local functions_table = lua.get_functions_table()
local function find_function_no()
  local number = math.random(0xFFFFFF)
  if functions_table[number] then return find_function_no() end
  return number
end
local stepper = nil
local stack   = { }
local fid     = find_function_no()
local goback  = "\\luafunction"..fid.."\\relax"

function tex.resume()
  if coroutine.status(stepper) == "dead" then
    stepper = table.remove(stack)
    print("stack change", #stack)
  end
  if stepper then
    print("obnovujeme")
    coroutine.resume(stepper)
  end
end
functions_table[fid] = tex.resume
-- function tex.yield()
--   tex.sprint(goback)
--   coroutine.yield()
--   texio.closeinput()
-- end
if texio.closeinput then
  function tex.yield()
    print("close input")
    tex.sprint(goback)
    coroutine.yield()
    texio.closeinput()
  end
else
  function tex.yield()
    print("no close")
    tex.sprint(goback)
    coroutine.yield()
    -- texio.closeinput()
  end
end
function tex.routine(f)
  table.insert(stack,stepper)
  stepper = coroutine.create(f)
  tex.sprint(goback)
end
