desc "Run end-to-end tests against a real wnd daemon (requires wnd running)"
task "test:e2e" do
  ENV["E2E"] = "1"
  Rake::Task["test"].invoke("test/e2e")
end
