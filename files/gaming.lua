local gaming_flag = (os.getenv("HOME") or "") .. "/.local/state/omarchy/toggles/gaming"

local file = io.open(gaming_flag, "r")
if not file then
  return
end
file:close()

hl.config({
  render = {
    direct_scanout = 1,
  },

  animations = {
    enabled = false,
  },

  decoration = {
    shadow = {
      enabled = false,
    },
    blur = {
      enabled = false,
    },
    rounding = 0,
  },
})

hl.workspace_rule({
  workspace = "name:gaming",
  gaps_in = 0,
  gaps_out = 0,
  border_size = 0,
  no_rounding = true,
  no_shadow = true,
  decorate = false,
})

hl.window_rule({
  match = {
    class = "^cs2$",
  },
  immediate = true,
})
