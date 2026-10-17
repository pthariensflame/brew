# typed: true
# frozen_string_literal: true

require "utils/disclaim"

RSpec.describe Utils::Disclaim do
  let(:functions) do
    %w[posix_spawnattr_init posix_spawnattr_setflags responsibility_spawnattrs_setdisclaim
       posix_spawn posix_spawnattr_destroy].to_h do |name|
      [name, instance_double(Fiddle::Function, call: 0)]
    end
  end

  before do
    stub_const("Fiddle::Handle::DEFAULT", instance_double(Fiddle::Handle))
    functions.each.with_index do |(name, function), address|
      allow(Fiddle::Handle::DEFAULT).to receive(:[]).with(name).and_return(address)
      allow(Fiddle::Function).to receive(:new).with(address, anything, Fiddle::TYPE_INT).and_return(function)
    end
    allow(functions.fetch("posix_spawn")).to receive(:call) { throw :exec }
    allow(Kernel).to receive(:exec) { throw :exec }
  end

  it "disclaims responsibility and replaces the launcher process" do
    expect(functions.fetch("posix_spawnattr_init")).to receive(:call).ordered
    expect(functions.fetch("posix_spawnattr_setflags")).to receive(:call).with(anything, 0x0040).ordered
    expect(functions.fetch("responsibility_spawnattrs_setdisclaim")).to receive(:call).with(anything, 1).ordered
    expect(functions.fetch("posix_spawn")).to receive(:call).ordered

    catch(:exec) { described_class.exec(["/bin/echo", "hello world"]) }
  end

  it "passes arguments and the environment without shell interpretation" do
    ENV["HOMEBREW_DISCLAIM_TEST"] = "hello world"
    expect(functions.fetch("posix_spawn")).to receive(:call) do |pid, path, actions, _attributes, argv, envp|
      expect([pid, path, actions, argv.unpack("p*"), envp.unpack("p*").grep(/HOMEBREW_DISCLAIM_TEST/)]).to eq(
        [nil, "/bin/echo", nil, ["/bin/echo", "$(exit 1)", "", nil], ["HOMEBREW_DISCLAIM_TEST=hello world"]],
      )
      throw :exec
    end

    catch(:exec) { described_class.exec(["/bin/echo", "$(exit 1)", ""]) }
  end

  it "stops when any native setup or spawn call fails" do
    %w[posix_spawnattr_init posix_spawnattr_setflags posix_spawn].each do |name|
      allow(functions.fetch(name)).to receive(:call).and_return(Errno::EPERM::Errno)

      expect { described_class.exec(["/bin/echo"]) }.to raise_error(Errno::EPERM, /#{name}/)

      allow(functions.fetch(name)).to receive(:call).and_return(0)
    end
  end

  it "destroys initialised attributes when spawning fails" do
    allow(functions.fetch("posix_spawn")).to receive(:call).and_return(Errno::ENOENT::Errno)
    expect(functions.fetch("posix_spawnattr_destroy")).to receive(:call)

    begin
      described_class.exec(["/missing"])
    rescue Errno::ENOENT
      nil
    end
  end

  it "does not destroy uninitialised attributes" do
    allow(functions.fetch("posix_spawnattr_init")).to receive(:call).and_return(Errno::ENOMEM::Errno)
    expect(functions.fetch("posix_spawnattr_destroy")).not_to receive(:call)

    begin
      described_class.exec(["/bin/echo"])
    rescue Errno::ENOMEM
      nil
    end
  end

  it "keeps the sandbox command when the private API is unavailable" do
    allow(Fiddle::Handle::DEFAULT).to receive(:[]).with("responsibility_spawnattrs_setdisclaim")
                                                  .and_raise(Fiddle::DLError)
    expect(functions.fetch("posix_spawnattr_init")).not_to receive(:call)
    expect(Kernel).to receive(:exec).with(["/usr/bin/sandbox-exec", "/usr/bin/sandbox-exec"],
                                          "-p", "(allow default)", "/bin/echo", "$(exit 1)")

    expect do
      catch(:exec) do
        described_class.exec(["/usr/bin/sandbox-exec", "-p", "(allow default)", "/bin/echo", "$(exit 1)"])
      end
    end.to output(/privacy permission isolation is unavailable/).to_stderr
  end

  it "keeps the sandbox command when the private API rejects the request" do
    allow(functions.fetch("responsibility_spawnattrs_setdisclaim")).to receive(:call).and_return(Errno::EINVAL::Errno)
    expect(functions.fetch("posix_spawn")).not_to receive(:call)
    expect(functions.fetch("posix_spawnattr_destroy")).to receive(:call)
    expect(Kernel).to receive(:exec).with(["/usr/bin/sandbox-exec", "/usr/bin/sandbox-exec"],
                                          "-p", "(allow default)", "/bin/echo", "hello world")

    expect do
      catch(:exec) do
        described_class.exec(["/usr/bin/sandbox-exec", "-p", "(allow default)", "/bin/echo", "hello world"])
      end
    end.to output(/privacy permission isolation is unavailable/).to_stderr
  end

  it "rejects arguments containing null bytes" do
    expect { described_class.exec(["/bin/echo", "hello\0world"]) }.to raise_error(ArgumentError, /null byte/)
  end

  it "changes native responsibility or warns without changing the PID", :needs_macos do
    result = SystemCommand.run!(
      RbConfig.ruby,
      args: ["-r", HOMEBREW_LIBRARY_PATH/"utils/disclaim", "-e",
             'ENV["HOMEBREW_DISCLAIM_PID"] = Process.pid.to_s; Utils::Disclaim.exec(ARGV)', "--",
             RbConfig.ruby, "-r", HOMEBREW_LIBRARY_PATH/"standalone", "-rfiddle", "-e", <<~RUBY],
               responsible = Fiddle::Function.new(
                 Fiddle::Handle::DEFAULT["responsibility_get_pid_responsible_for_pid"],
                 [Fiddle::TYPE_INT], Fiddle::TYPE_INT
               ).call(Process.pid)
               abort "PID changed" unless Process.pid == ENV.fetch("HOMEBREW_DISCLAIM_PID").to_i
               puts responsible == Process.pid
             RUBY
    )
    expect(result.stdout + result.stderr)
      .to match(/^true$|^Warning: macOS privacy permission isolation is unavailable\./)
  end
end
