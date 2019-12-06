-- The coroutine code is taken from: 
-- Hans Hagen. Executing TeX in Lua: Coroutines. TUGboat, 2018, vol 39, n. 1. 
-- https://tug.org/TUGboat/tb39-1/tb121hagen-exec.pdf

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
    -- print("stack change", #stack)
  end
  if stepper then
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
    tex.sprint(goback)
    coroutine.yield()
    texio.closeinput()
  end
else
  function tex.yield()
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

-- execute the Lua code if it is ready
local function execute(tbl, command)
  if tbl.cmd_depth < 2 then
    -- use the 
    print("jsme tu", command)
    print "-----------------"
    print(command)
    tex.sprint(command)
    -- go back to TeX
    if stepper then 
      print "jsme v coroutine"
      tex.yield()
    end
    -- tex.sprint(goback)
    -- tex.resume()
  end
end

local function default_unit(x)
  -- convert number to pt
  if type(x) == "number" then return string.format(tostring(x) .. "pt") end
  -- or return the unmodified argument
  return x
end



local function process_parameter(par)
  local function mandatory(x) return "{" .. x .. "}" end
  local function optional(x) return "[" .. x .. "]" end
  -- put argument into brackets if it contains spaces, don't modify it otherwise
  local function escape_ws(x) if x:match("%s") then return mandatory(x) else return x end end

  if type(par) == "table" then
    -- pass optional arguments as tables
    -- here are two types -- switches and key-vals
    local values = {}
    for k,v in pairs(par) do
      if type(k) == "number" then -- switch
        values[#values+1] = escape_ws(default_unit(v))
      else
        local val = escape_ws(default_unit(v))
        values[#values+1] = string.format("%s=%s", k, val)
      end
    end
    return optional(table.concat(values, ","))
  elseif type(par) == "number" then
    -- shortcut for numeric values. They will be converted to pt units
    return mandatory(default_unit(par))
  else
    return mandatory(par)
  end
end

local environment_stack = {}

local function process_command(tbl, cmd)
  -- match special commands
  if cmd:match("^_") then
    -- because end is a keyword, we need to handle it specially. texlib.end{document} produces syntax error
    --
    local env 
    if cmd == "_end" then
      -- remove the current environment from stack
      env = table.remove(tbl.stack)
      return "\n\\end{" .. env .. "}\n"
    elseif cmd == "_crlf" then
      return "\\\\"
    else
      -- environments should start with _begin and continue with the env name
      -- texlib._begindocument
      local env = cmd:match("_begin(.+)")
      if env then
        table.insert(tbl.stack, env)
        return "\n\\begin{" ..env .. "}\n"
      end
    end
  end
  return "\\" .. cmd
end

local texlib = setmetatable({
  stack={}, -- keep the current LaTeX environment
  cmd_depth = 0 -- enable nested commands
}
  ,{
  -- enable texlib.texcommand(parameters) calling
  __index = function(tbl, command)
    -- we keep the depth to support nested commands like texlibe.a(texlib.b("x"))
    tbl.cmd_depth = tbl.cmd_depth + 1
    -- the TeX command is contained in the command parameter. value isn't used
    -- the returned function will process command parameters
    return function(...)
      local parameters = {...}
      local params_to_tex = {}
      if parameters[1] == false then
        -- parameters to TeX primitives with non standard syntax can be 
        -- passed using: texlib.name(false, "direct argument")
        params_to_tex = {parameters[2]}
      else
        for _, par in ipairs(parameters) do
          params_to_tex[#params_to_tex + 1] = process_parameter(par)
        end
      end
      local real_command = process_command(tbl, command)
      local tex_code = real_command .. table.concat(params_to_tex)
      execute(tbl, tex_code)
      tbl.cmd_depth = tbl.cmd_depth - 1
      return tex_code
    end
  end,
  __call = function(tbl, text)
    -- space between command can be added using texlib(), newline inserted using texlib(true)
    if text == nil then text = " " elseif text == true then text="\n" end
    execute(tbl ,text)
    return text
  end

}
)

-- texlib.hello "tex"
-- texlib.hello {12}
-- texlib.hello {"12"}


-- texlib.textit(texlib.textbf "hello bold italic")
-- texlib._begindocument ()
-- texlib._begintabular "l l l"
-- texlib._end ()
-- texlib._end ()
-- texlib.begingroup()
-- texlib.endgroup()
-- texlib._()
-- texlib "ahoj"

return texlib
