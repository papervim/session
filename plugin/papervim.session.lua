local session = require "papervim.session"

local actions = {
  delete = function(item)
    local session_dir = session.session_file_dir(item)
    if vim.fn.isdirectory(session_dir) == 1 then
      vim.fs.rm(session_dir, { force = true, recursive = true })
      vim.api.nvim_echo({ { "deleted session: " .. item } }, true, {})
    else
      vim.api.nvim_echo({ { "session not exists: " .. item } }, true, { kind = "wmsg" })
    end
  end,
  load = session.read,
  inspect = function(item)
    vim.cmd.edit(vim.fn.fnameescape(session.session_file(item)))
  end,
}

---@param action? string
local function select(action)
  local action = action or "inspect"
  local f = actions[action]
  local on_choice = f
      and function(dir) if dir then f(dir) end end
      or vim.print

  vim.ui.select(session.items(), {
    prompt = action .. " session: ",
    preview_item = session.get_opts().preview,
  }, on_choice)
end

vim.api.nvim_create_user_command("Project", function(args)
  local action = args.fargs[1]
  if #args.fargs < 2 then
    select(action)
    return
  end
  local item = args.fargs[2]
  local cb = actions[action]
  if cb then return cb(item) end
end, {
  ---@param cmd_line string
  complete = function(_arg_lead, cmd_line, _cursor_pos)
    local args = vim.iter(cmd_line:gmatch "%S+"):totable()
    if #args == 1 then
      return vim.tbl_keys(actions)
    else
      return session.items()
    end
  end,
  nargs = "*",
})
