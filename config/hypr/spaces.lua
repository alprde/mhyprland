-- macOS "Spaces" mantığı:
--   * Her ekranın kendi masaüstü listesi vardır; geçiş yalnızca odaktaki ekranı değiştirir.
--   * Masaüstü yalnızca Mission Control'deki + ile eklenir, üzerindeki × ile silinir. Kaydırma/tilt uçlarda durur.
--   * Boş masaüstleri silinene kadar kalır (yeniden başlatmada da).
-- Hyprland'de masaüstü numaraları ekranlar arasında ortak olduğu için her ekrana 10'luk bir aralık ayrılır
-- (1-10 dahili ekran, 11-20 ilk harici ekran, …). Arayüzde numara değil, ekrandaki SIRA gösterilir.
-- Dışarıdan çağrı:  hyprctl eval 'TahoeSpaces.add("DP-1")'
local PER = 10
local FILE = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/tahoe/spaces.state"
local S = {}
local mons = {}    -- ekran adı → { slot = n, ids = { … } }
local rules = {}   -- masaüstü numarası → Hyprland kuralı

-- ---- kayıt: her satır "ekran dilim numara numara …" ----
local function load()
  local f = io.open(FILE, "r")
  if not f then return end
  for line in f:lines() do
    local name, slot, rest = line:match("^(%S+)%s+(%d+)%s*(.*)$")
    if name then
      local ids = {}
      for id in rest:gmatch("%d+") do ids[#ids + 1] = tonumber(id) end
      mons[name] = { slot = tonumber(slot), ids = ids }
    end
  end
  f:close()
end

local function save()
  os.execute("mkdir -p '" .. FILE:match("^(.*)/") .. "'")
  local f = io.open(FILE, "w")
  if not f then return end
  for name, m in pairs(mons) do f:write(name, " ", m.slot, " ", table.concat(m.ids, " "), "\n") end
  f:close()
end

-- ---- Hyprland kuralları: listedeki her masaüstü kalıcıdır ve kendi ekranına bağlıdır ----
local function set_rule(id, name, first)
  if rules[id] then rules[id]:set_enabled(false) end
  rules[id] = hl.workspace_rule({ workspace = tostring(id), monitor = name, persistent = true, default = first })
end

local function drop_rule(id)
  if rules[id] then rules[id]:set_enabled(false); rules[id] = nil end
end

local function apply(name)
  table.sort(mons[name].ids)
  for i, id in ipairs(mons[name].ids) do set_rule(id, name, i == 1) end
end

local function free_slot(want)
  local used = {}
  for _, m in pairs(mons) do used[m.slot] = true end
  local s = want
  while used[s] do s = s + 1 end
  return s
end

-- ekranı tanı (ilk kez görülüyorsa bir dilim ve tek masaüstü ver); 0. dilim dahili ekrana ayrılır
local function ensure(name)
  if mons[name] or name:match("^HEADLESS") then return mons[name] end
  local slot = free_slot(name:match("^eDP") and 0 or 1)
  mons[name] = { slot = slot, ids = { slot * PER + 1 } }
  apply(name); save()
  return mons[name]
end

local function owner(id)
  for name, m in pairs(mons) do
    for i, v in ipairs(m.ids) do if v == id then return name, i end end
  end
end

local function exists(id)
  for _, w in ipairs(hl.get_workspaces()) do if w.id == id then return true end end
  return false
end

local function free_id(m)
  for id = m.slot * PER + 1, m.slot * PER + PER do
    if not owner(id) and not exists(id) then return id end
  end
end

-- ekrandaki masaüstleri, sırayla (takılı olmayan ekrandan buraya taşınanlar da sona eklenir)
local function on_monitor(name)
  local out = {}
  for _, w in ipairs(hl.get_workspaces()) do
    if w.id > 0 and w.monitor and w.monitor.name == name then out[#out + 1] = w.id end
  end
  table.sort(out)
  return out
end

-- listede olmayan mevcut masaüstlerini (ör. ilk geçişte "2") ekranın aralığına al
local function adopt()
  local list = {}
  for _, w in ipairs(hl.get_workspaces()) do
    if w.id > 0 and w.monitor and not owner(w.id) then list[#list + 1] = { id = w.id, mon = w.monitor.name, windows = w.windows } end
  end
  table.sort(list, function(a, b) return a.id < b.id end)
  for _, w in ipairs(list) do
    local m = ensure(w.mon)
    if m then
      local base, id = m.slot * PER, w.id
      if id <= base or id > base + PER then
        -- boş olan ilk masaüstüne denk gelen aralık dışı masaüstü doğrudan onun numarasını alır
        local first = m.ids[1]
        id = (first and not exists(first)) and first or free_id(m)
        if id then
          hl.dispatch(hl.dsp.workspace.change_id({ workspace = w.id, id = id }))
        end
      end
      if id then
        if not owner(id) then m.ids[#m.ids + 1] = id end
        apply(w.mon)
      end
    end
  end
  save()
end

local function sync()
  for _, m in ipairs(hl.get_monitors()) do ensure(m.name) end
  adopt()
end

-- ---- kullanıcı eylemleri ----
local function focused()
  local mon = hl.get_active_monitor()
  if mon and mon.active_workspace then return mon, mon.active_workspace.id end
end

-- ileri/geri: uçlarda durur, yeni masaüstü açmaz
function S.step(dir)
  local mon, cur = focused()
  if not mon then return end
  local ids = on_monitor(mon.name)
  for i, id in ipairs(ids) do
    if id == cur then
      if ids[i + dir] then hl.dispatch(hl.dsp.focus({ workspace = ids[i + dir] })) end
      return
    end
  end
end

-- odaktaki ekranın n. masaüstüne geç / pencereyi oraya taşı
function S.go(n)
  local mon = focused()
  local id = mon and on_monitor(mon.name)[n]
  if id then hl.dispatch(hl.dsp.focus({ workspace = id })) end
end

function S.move(n)
  local mon = focused()
  local id = mon and on_monitor(mon.name)[n]
  if id then hl.dispatch(hl.dsp.window.move({ workspace = id })) end
end

-- + : ekrana yeni masaüstü ekle (verilirse bir pencereyi de oraya taşı); geçiş yapmaz
function S.add(name, address)
  local m = ensure(name)
  local id = m and #on_monitor(name) < PER and free_id(m)
  if not id then return end
  m.ids[#m.ids + 1] = id
  apply(name); save()
  if address then hl.dispatch(hl.dsp.window.move({ workspace = id, follow = false, window = "address:" .. address })) end
end

-- × : masaüstünü sil; pencereleri soldakine (ilkse sağdakine) geçer. Ekranın son masaüstü silinemez.
function S.remove(id)
  local mon
  for _, w in ipairs(hl.get_workspaces()) do
    if w.id == id and w.monitor then mon = w.monitor end
  end
  if not mon then return end
  local ids, target = on_monitor(mon.name), nil
  if #ids < 2 then return end
  for i, v in ipairs(ids) do if v == id then target = ids[i - 1] or ids[i + 1] end end
  local moving = {}
  for _, w in ipairs(hl.get_windows()) do
    if w.workspace and w.workspace.id == id then moving[#moving + 1] = w.address end
  end
  for _, a in ipairs(moving) do
    local sel = tostring(a):match("^0x") and a or ("0x" .. a)
    hl.dispatch(hl.dsp.window.move({ workspace = target, follow = false, window = "address:" .. sel }))
  end
  local name, i = owner(id)
  if name then table.remove(mons[name].ids, i) end
  drop_rule(id)
  if mon.active_workspace and mon.active_workspace.id == id then
    local back = hl.get_active_monitor()
    hl.dispatch(hl.dsp.focus({ workspace = target }))
    if back and back.name ~= mon.name then hl.dispatch(hl.dsp.focus({ monitor = back.name })) end
  end
  if name then apply(name) end
  save()
end

S.sync = sync
load()
for name in pairs(mons) do apply(name) end
-- yapılandırma yeniden yüklenince ekranlar zaten vardır; ilk açılışta ise olaylarla gelir
local function later() hl.timer(sync, { timeout = 600, type = "oneshot" }) end
hl.on("monitor.added", later)
hl.on("hyprland.start", later)
if #hl.get_monitors() > 0 then later() end

TahoeSpaces = S
return S
