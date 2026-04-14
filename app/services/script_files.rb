class ScriptFiles
  class Error < StandardError; end
  class SandboxError < Error; end
  class FileNotFound < Error; end
  class QuotaExceeded < Error; end

  MAX_FILE_SIZE = 25.megabytes
  MAX_TOTAL_SIZE = 100.megabytes

  def initialize(bot, root: nil)
    @root = Pathname.new(root || Rails.root.join("storage", "bot_files", bot.id.to_s))
  end

  def read(path)
    full = safe_path(path)
    raise FileNotFound, path unless File.file?(full)
    File.binread(full)
  end

  def write(path, content)
    full = safe_path(path)
    content_str = content.to_s
    bytes = content_str.bytesize

    raise QuotaExceeded, "file exceeds #{MAX_FILE_SIZE / 1.megabyte} MB limit" if bytes > MAX_FILE_SIZE

    existing_size = File.exist?(full) && File.file?(full) ? File.size(full) : 0
    projected = total_usage - existing_size + bytes
    raise QuotaExceeded, "total storage would exceed #{MAX_TOTAL_SIZE / 1.megabyte} MB limit" if projected > MAX_TOTAL_SIZE

    ensure_root!
    FileUtils.mkdir_p(File.dirname(full))
    File.open(full, "wb", 0644) do |f|
      f.flock(File::LOCK_EX)
      f.write(content_str)
    end
    @total_usage = projected
    nil
  end

  def list(path = ".")
    full = safe_path(path, allow_root: true)
    return [] unless Dir.exist?(full)

    entries = Dir.children(full).reject { |name| name.start_with?(".") }
    dirs, files = entries.partition { |name| File.directory?(File.join(full, name)) }
    dirs.sort.map { |d| "#{d}/" } + files.sort
  end

  def exists?(path)
    full = safe_path(path)
    File.exist?(full)
  end

  def delete(path)
    full = safe_path(path)
    return false unless File.exist?(full) && File.file?(full)

    size = File.size(full)
    File.delete(full)
    @total_usage = total_usage - size if @total_usage
    true
  end

  def total_usage
    @total_usage ||= calculate_total_usage
  end

  def tree
    return [] unless Dir.exist?(@root)

    Dir.glob(File.join(@root, "**", "*"))
      .reject { |f| File.basename(f).start_with?(".") }
      .map { |f| tree_entry(f) }
      .sort_by { |e| [ e[:dir] ? 0 : 1, e[:path] ] }
  end

  def safe_path(user_path, allow_root: false)
    user_path = user_path.to_s.strip
    raise SandboxError, "path is empty" if user_path.empty?
    raise SandboxError, "path contains null byte" if user_path.include?("\0")

    full = File.expand_path(user_path, @root)
    root_str = @root.to_s

    unless full.start_with?("#{root_str}/") || (allow_root && full == root_str)
      raise SandboxError, "path escapes sandbox: #{user_path}"
    end

    check = full
    while check != root_str && check != "/"
      raise SandboxError, "symlink in path: #{user_path}" if File.symlink?(check)
      check = File.dirname(check)
    end

    full
  end

  private

  def ensure_root!
    FileUtils.mkdir_p(@root) unless Dir.exist?(@root)
  end

  def tree_entry(full_path)
    rel = Pathname.new(full_path).relative_path_from(@root).to_s
    is_dir = File.directory?(full_path)
    {
      path: rel,
      name: File.basename(rel),
      dir: is_dir,
      depth: rel.count("/"),
      size: is_dir ? nil : File.size(full_path),
      modified: File.mtime(full_path)
    }
  end

  def calculate_total_usage
    return 0 unless Dir.exist?(@root)
    Dir.glob(File.join(@root, "**", "*"))
      .select { |f| File.file?(f) }
      .sum { |f| File.size(f) }
  end
end
