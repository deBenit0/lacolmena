-- Ejecuta todas las pruebas: lua5.1 tests/run.lua
local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")
math.randomseed(tonumber(os.getenv("SEED") or "12345"))

local files = { "test_codec.lua", "test_data.lua", "test_sync.lua", "test_ui.lua", "test_stress.lua", "test_storm.lua", "test_mail.lua", "test_easy.lua", "test_new.lua", "test_catalog.lua", "test_dungeons.lua", "test_offers.lua" }
for _, file in ipairs(files) do
  H.Reset()
  print("== " .. file)
  local chunk = assert(loadfile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/" .. file))
  local ok, err = pcall(chunk, H)
  if not ok then
    H.failures = H.failures + 1
    print("  ERROR: " .. tostring(err))
  end
end
print(string.format("\n%d comprobaciones correctas, %d fallos, %d errores de Lua", H.passes, H.failures, #H.errors))
os.exit((H.failures == 0 and #H.errors == 0) and 0 or 1)
