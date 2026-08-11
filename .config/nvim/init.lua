local autocmd = vim.api.nvim_create_autocmd

local function indent(et, ts)
  vim.bo.expandtab = et
  vim.bo.tabstop = ts
  vim.bo.shiftwidth = ts
  vim.bo.softtabstop = ts
end

-- Scripts
autocmd("FileType", {
  pattern = { "sh", "bash", "fish", "zsh", "lua", "dosbatch", "ps1" },
  callback = function()
    indent(false, 2)
  end,
})

-- Python
autocmd("FileType", {
  pattern = "python",
  callback = function()
    indent(true, 4)
  end,
})

-- Rust
autocmd("FileType", {
  pattern = "rust",
  callback = function()
    indent(true, 4)
  end,
})

-- JSON
autocmd("FileType", {
  pattern = "json",
  callback = function()
    indent(true, 4)
  end,
})

-- YAML
autocmd("FileType", {
  pattern = { "yaml", "yml" },
  callback = function()
    indent(true, 2)
  end,
})

-- C
autocmd("FileType", {
  pattern = { "c", "cpp", "make" },
  callback = function()
    indent(false, 8)
  end,
})


-- set filetype?
