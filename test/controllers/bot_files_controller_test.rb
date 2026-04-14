require "test_helper"

class BotFilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    @wnd = WndStubFactory.new
    BotsController.wnd_client_class = @wnd
    @bot = bots(:relay_bot)
    @tmp_root = Dir.mktmpdir("botburrow-test-files")
    @original_root_method = ScriptFiles.instance_method(:initialize)
    tmp_root = @tmp_root
    bot_id = @bot.id
    ScriptFiles.define_method(:initialize) do |bot, root: nil|
      @root = Pathname.new(root || (bot.id == bot_id ? tmp_root : Rails.root.join("storage", "bot_files", bot.id.to_s)))
    end
  end

  teardown do
    BotsController.wnd_client_class = Wnd::Client
    ScriptFiles.define_method(:initialize, @original_root_method)
    FileUtils.remove_entry(@tmp_root) if @tmp_root && Dir.exist?(@tmp_root)
  end

  # -- Authentication --

  test "unauthenticated user is redirected to login" do
    sign_out
    get download_bot_files_path(@bot, path: "any.txt")
    assert_redirected_to new_session_path
  end

  # -- Upload --

  test "uploading a file saves it and redirects" do
    file = fixture_file_upload("test_upload.txt", "text/plain")
    post bot_files_path(@bot), params: { file: file }
    assert_redirected_to bot_path(@bot, anchor: "files")

    assert File.exist?(File.join(@tmp_root, "test_upload.txt"))
  end

  test "uploading with no file shows alert" do
    post bot_files_path(@bot), params: {}
    assert_redirected_to bot_path(@bot, anchor: "files")
    assert_equal "No file selected.", flash[:alert]
  end

  test "uploading sanitizes dangerous filenames" do
    file = fixture_file_upload("test_upload.txt", "text/plain")
    file.define_singleton_method(:original_filename) { "../../../etc/passwd" }
    post bot_files_path(@bot), params: { file: file }
    assert_redirected_to bot_path(@bot, anchor: "files")

    assert File.exist?(File.join(@tmp_root, "passwd"))
    assert_not File.exist?(File.join(@tmp_root, "..", "..", "..", "etc", "passwd"))
  end

  # -- Download --

  test "downloading a file returns attachment" do
    write_file("download_me.txt", "file content")
    get download_bot_files_path(@bot, path: "download_me.txt")
    assert_response :success
    assert_equal "file content", response.body
    assert_match "attachment", response.headers["Content-Disposition"]
  end

  test "downloading a missing file returns 404" do
    get download_bot_files_path(@bot, path: "nope.txt")
    assert_response :not_found
  end

  test "downloading with path traversal returns 404" do
    get download_bot_files_path(@bot, path: "../../etc/passwd")
    assert_response :not_found
  end

  # -- Delete --

  test "deleting a file removes it and redirects" do
    write_file("doomed.txt", "bye")
    delete bot_files_path(@bot, path: "doomed.txt")
    assert_redirected_to bot_path(@bot, anchor: "files")
    assert_equal "File deleted.", flash[:notice]
    assert_not File.exist?(File.join(@tmp_root, "doomed.txt"))
  end

  test "deleting a missing file shows not found" do
    delete bot_files_path(@bot, path: "ghost.txt")
    assert_redirected_to bot_path(@bot, anchor: "files")
    assert_equal "File not found.", flash[:alert]
  end

  test "deleting with invalid path shows alert" do
    delete bot_files_path(@bot, path: "../../etc/passwd")
    assert_redirected_to bot_path(@bot, anchor: "files")
    assert_equal "Invalid file path.", flash[:alert]
  end

  private

  def write_file(name, content)
    FileUtils.mkdir_p(@tmp_root)
    File.binwrite(File.join(@tmp_root, name), content)
  end
end
