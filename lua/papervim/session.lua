---@class papervim.session.opts
---@field storage? string
---@field encode_path? fun(dir: string): string
---@field hooks? papervim.session.hooks
---@field preview? fun(item: string): { buf?: integer, pos?: [integer, integer], pos_end?: [integer, integer] }
---@field autosave? fun(pwd: string): boolean

---@class papervim.session.hooks
---@field read? { pre: fun(item: string), post: fun(item: string) }
---@field write? { pre: fun(item: string), post: fun(item: string) }

local function clean_bufs_and_set_ft()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_get_option_value("buftype", { buf = buf }) ~= "" then goto continue end
    local name = vim.api.nvim_buf_get_name(buf)
    if vim.fn.filereadable(name) == 0 then
      vim.api.nvim_buf_delete(buf, {})
      goto continue
    end
    local ft = vim.filetype.match { buf = buf }
    if ft then
      vim.api.nvim_set_option_value("filetype", ft, { buf = buf })
    end
    ::continue::
  end
end

---@type papervim.session.opts
local config = {
  storage = vim.fn.stdpath "state" .. "/session",
  encode_path = function(dir)
    return (vim.fs.normalize(vim.fs.abspath(dir)):gsub("%%", "%%%%"):gsub("/", "%%"))
  end,
  hooks = {
    read = { pre = function() end, post = clean_bufs_and_set_ft },
    write = { pre = function() end, post = function() end },
  },
  autosave = function(cwd)
    return vim.fn.isdirectory(vim.fs.joinpath(cwd, ".git")) == 1
  end,
}

---@param item string
local session_file_dir = function(item)
  return vim.fs.joinpath(config.storage, item)
end

---@param item string
local session_file = function(item)
  return vim.fs.joinpath(config.storage, item, "Session.vim")
end

---@param item string
local function read(item)
  config.hooks.read.pre(item)
  vim.cmd.source(vim.fn.fnameescape(session_file(item)))
  config.hooks.read.post(item)
end

---@param item string
local function write(item)
  vim.fn.mkdir(session_file_dir(item), "p")
  config.hooks.write.pre(item)
  vim.cmd.mksession {
    args = { vim.fn.fnameescape(session_file(item)) },
    bang = true,
  }
  config.hooks.write.post(item)
end

local group = vim.api.nvim_create_augroup("papervim.session", { clear = true })

---@param item string
local function session_exists(item)
  return vim.fn.filereadable(session_file(item)) == 1
end

---@param dir string
local function on_dir_changed(dir)
  if vim.v.this_session ~= "" then return end

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      local cwd = vim.fn.getcwd(-1, -1)
      if config.autosave(cwd) then write(config.encode_path(cwd)) end
    end,
    desc = "save project",
  })
  local item = config.encode_path(dir)
  if session_exists(item) then read(item) end
end

return {
  ---@param opts? papervim.session.opts
  setup = function(opts)
    if opts then
      config = vim.tbl_deep_extend("force", config, opts)
    end
  end,
  get_opts = function()
    return config
  end,
  read = read,
  on_dir_changed = on_dir_changed,
  group = group,

  session_file_dir = session_file_dir,
  session_file = session_file,
  ---@return string[]
  items = function()
    return vim.iter(vim.fs.dir(config.storage))
        :map(function(name, _type) return name end)
        :filter(session_exists):totable()
  end,

  clean_bufs_and_set_ft = clean_bufs_and_set_ft,
}
