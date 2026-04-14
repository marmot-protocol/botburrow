require "test_helper"

class ScriptFilesTest < ActiveSupport::TestCase
  setup do
    @bot = Bot.create!(name: "FileBot", npub: SecureRandom.hex(32))
    @tmp_root = Dir.mktmpdir("botburrow-test-files")
    @files = ScriptFiles.new(@bot, root: @tmp_root)
  end

  teardown do
    FileUtils.remove_entry(@tmp_root) if @tmp_root && Dir.exist?(@tmp_root)
  end

  # -- Read / Write --

  test "write and read roundtrip" do
    @files.write("hello.txt", "Hello, world!")
    assert_equal "Hello, world!", @files.read("hello.txt")
  end

  test "read returns binary encoding" do
    @files.write("bin.dat", "\xFF\xFE".b)
    data = @files.read("bin.dat")
    assert_equal Encoding::ASCII_8BIT, data.encoding
    assert_equal "\xFF\xFE".b, data
  end

  test "read raises FileNotFound for missing file" do
    assert_raises(ScriptFiles::FileNotFound) { @files.read("nope.txt") }
  end

  test "read raises FileNotFound for directory path" do
    @files.write("sub/file.txt", "x")
    assert_raises(ScriptFiles::FileNotFound) { @files.read("sub") }
  end

  test "write auto-creates parent directories" do
    @files.write("deep/nested/dir/file.txt", "content")
    assert_equal "content", @files.read("deep/nested/dir/file.txt")
  end

  test "write overwrites existing file" do
    @files.write("data.txt", "first")
    @files.write("data.txt", "second")
    assert_equal "second", @files.read("data.txt")
  end

  test "write converts non-string content via to_s" do
    @files.write("num.txt", 42)
    assert_equal "42", @files.read("num.txt")
  end

  # -- List --

  test "list returns files and directories at root" do
    @files.write("a.txt", "a")
    @files.write("b.txt", "b")
    @files.write("sub/c.txt", "c")

    entries = @files.list
    assert_includes entries, "a.txt"
    assert_includes entries, "b.txt"
    assert_includes entries, "sub/"
  end

  test "list returns contents of subdirectory" do
    @files.write("reports/daily.json", "{}")
    @files.write("reports/weekly.json", "{}")

    entries = @files.list("reports")
    assert_equal %w[daily.json weekly.json], entries
  end

  test "list excludes dotfiles" do
    @files.write(".hidden", "secret")
    @files.write("visible.txt", "public")

    assert_equal ["visible.txt"], @files.list
  end

  test "list returns empty array for missing directory" do
    assert_equal [], @files.list("nonexistent")
  end

  test "list returns sorted entries with directories first" do
    @files.write("zebra.txt", "z")
    @files.write("alpha.txt", "a")
    @files.write("mid/file.txt", "m")

    entries = @files.list
    assert_equal ["mid/", "alpha.txt", "zebra.txt"], entries
  end

  # -- Exists / Delete --

  test "exists? returns true for existing file" do
    @files.write("here.txt", "yes")
    assert @files.exists?("here.txt")
  end

  test "exists? returns false for missing file" do
    assert_not @files.exists?("gone.txt")
  end

  test "exists? returns true for directory" do
    @files.write("dir/file.txt", "x")
    assert @files.exists?("dir")
  end

  test "delete removes file and returns true" do
    @files.write("doomed.txt", "bye")
    assert @files.delete("doomed.txt")
    assert_not @files.exists?("doomed.txt")
  end

  test "delete returns false for missing file" do
    assert_not @files.delete("nope.txt")
  end

  test "delete returns false for directory" do
    @files.write("dir/file.txt", "x")
    assert_not @files.delete("dir")
  end

  # -- Path traversal --

  test "rejects path traversal with .." do
    assert_raises(ScriptFiles::SandboxError) { @files.read("../../etc/passwd") }
  end

  test "rejects path traversal with absolute path" do
    assert_raises(ScriptFiles::SandboxError) { @files.read("/etc/passwd") }
  end

  test "rejects null bytes in path" do
    assert_raises(ScriptFiles::SandboxError) { @files.read("file.txt\0.rb") }
  end

  test "rejects empty path" do
    assert_raises(ScriptFiles::SandboxError) { @files.read("") }
  end

  test "rejects whitespace-only path" do
    assert_raises(ScriptFiles::SandboxError) { @files.read("   ") }
  end

  test "rejects path resolving to root itself" do
    assert_raises(ScriptFiles::SandboxError) { @files.read(".") }
  end

  test "rejects symlinks in path" do
    real_dir = File.join(@tmp_root, "real")
    FileUtils.mkdir_p(real_dir)
    File.write(File.join(real_dir, "secret.txt"), "hidden")

    link_path = File.join(@tmp_root, "link")
    File.symlink(real_dir, link_path)

    assert_raises(ScriptFiles::SandboxError) { @files.read("link/secret.txt") }
  end

  # -- Size limits --

  test "write rejects file exceeding per-file limit" do
    big_content = "x" * (ScriptFiles::MAX_FILE_SIZE + 1)
    assert_raises(ScriptFiles::QuotaExceeded) { @files.write("big.bin", big_content) }
  end

  test "write rejects when total would exceed per-bot limit" do
    chunk = "x" * 24.megabytes
    @files.write("a.bin", chunk)
    @files.write("b.bin", chunk)
    @files.write("c.bin", chunk)
    @files.write("d.bin", chunk)  # 96 MB total, still under 100 MB
    assert_raises(ScriptFiles::QuotaExceeded) { @files.write("e.bin", chunk) }
  end

  test "overwriting a file reclaims quota" do
    @files.write("data.bin", "x" * 20.megabytes)
    # Overwrite with smaller content should succeed
    @files.write("data.bin", "small")
    assert_equal "small", @files.read("data.bin")
  end

  # -- Total usage --

  test "total_usage reflects files on disk" do
    assert_equal 0, @files.total_usage
    @files.write("a.txt", "hello")
    assert_equal 5, @files.total_usage
  end

  test "total_usage decreases after delete" do
    @files.write("a.txt", "hello")
    @files.delete("a.txt")
    assert_equal 0, @files.total_usage
  end

  # -- Lazy root creation --

  test "initialize does not create directory" do
    tmp = File.join(Dir.tmpdir, "botburrow-lazy-#{SecureRandom.hex(4)}")
    ScriptFiles.new(@bot, root: tmp)
    assert_not Dir.exist?(tmp)
  ensure
    FileUtils.remove_entry(tmp) if tmp && Dir.exist?(tmp)
  end

  test "write creates root directory on first write" do
    tmp = File.join(Dir.tmpdir, "botburrow-lazy-#{SecureRandom.hex(4)}")
    files = ScriptFiles.new(@bot, root: tmp)
    files.write("test.txt", "hi")
    assert Dir.exist?(tmp)
  ensure
    FileUtils.remove_entry(tmp) if tmp && Dir.exist?(tmp)
  end
end
