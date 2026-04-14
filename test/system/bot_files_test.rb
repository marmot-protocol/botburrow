require "application_system_test_case"
require_relative "../support/wnd_stub"

class BotFilesTest < ApplicationSystemTestCase
  setup do
    @wnd_stub = WndStubFactory.new
    BotsController.wnd_client_class = @wnd_stub
    @bot = bots(:relay_bot)
    @storage_root = Rails.root.join("storage", "bot_files", @bot.id.to_s).to_s
    sign_in
  end

  teardown do
    BotsController.wnd_client_class = Wnd::Client
    FileUtils.remove_entry(@storage_root) if Dir.exist?(@storage_root)
  end

  test "files tab shows empty state with code example" do
    visit bot_path(@bot)
    open_files_tab

    assert_text "No files yet"
    assert_text "files.read"
    assert_text "files.write"
  end

  test "upload a file and see it in the tree" do
    visit bot_path(@bot)
    open_files_tab

    attach_file "file", file_fixture("test_upload.txt")
    click_on "Upload"

    assert_text "uploaded"

    visit bot_path(@bot)
    open_files_tab
    assert_text "test_upload.txt"
  end

  test "delete an uploaded file" do
    seed_file("doomed.txt", "bye")
    visit bot_path(@bot)
    open_files_tab

    assert_text "doomed.txt"

    accept_confirm "Delete doomed.txt?" do
      find("a", text: "Delete", match: :first, exact_text: true).click
    end

    assert_text "File deleted"
  end

  test "files tab shows quota usage" do
    seed_file("data.txt", "x" * 1024)
    visit bot_path(@bot)
    open_files_tab

    assert_text "100 MB"
  end

  test "script editor reference includes files API" do
    visit new_bot_command_path(@bot)

    assert_text "files.read(path)"
    assert_text "files.write(path, content)"
    assert_text "files.list(path)"
    assert_text "files.exists?(path)"
    assert_text "files.delete(path)"
  end

  test "uploaded file appears in tree with size and actions" do
    seed_file("config.json", '{"key": "value"}')
    visit bot_path(@bot)
    open_files_tab

    assert_text "config.json"
    assert_text "Download"
  end

  private

  def open_files_tab
    find("button[data-tabs-id='files']").click
    # Retry if Stimulus controller hadn't connected on first click
    unless page.has_selector?("#files", visible: true, wait: 2)
      find("button[data-tabs-id='files']").click
    end
    assert_selector "#files", visible: true, wait: 5
  end

  def seed_file(name, content)
    FileUtils.mkdir_p(@storage_root)
    File.binwrite(File.join(@storage_root, name), content)
  end
end
