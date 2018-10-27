require("mod-gui")
require("util")

local default_orange_color = {r = 0.98, g = 0.66, b = 0.22}
local trivial_entity_types = {
  ["car"] = 1,
  ["curved-rail"] = 1,
  ["electric-pole"] = 1,
  ["heat-pipe"] = 1,
  ["lamp"] = 1,
  ["pipe"] = 1,
  -- ["pipe-to-ground"] = 1,
  -- ["splitter"] = 1,
  ["straight-rail"] = 1,
  ["transport-belt"] = 1,
  -- ["underground-belt"] = 1,
  ["wall"] = 1,
}

if not global.is_initialized then
  global.is_initialized = true
  global.chunk_queue = {}
  global.current_count = {}
  global.last_complete_count = {}
end

local function increment_count_table(the_table, key, increment_by)
  if the_table[key] then
    the_table[key] = the_table[key] + increment_by
  else
    the_table[key] = increment_by
  end
end

local function count_entities_in_chunk_by_player(surface, chunk)
  local count_entities = {}
  local area = {
    left_top = {x = chunk.x * 32, y = chunk.y * 32},
    right_bottom = {x = (chunk.x + 1) * 32, y = (chunk.y + 1) * 32}
  }
  local entities = surface.find_entities(area)
  for i=1, #entities do
    local entity = entities[i]
    if not trivial_entity_types[entity.type] and entity.last_user then
      increment_count_table(count_entities, entity.last_user.name, 1)
    end
  end
  return count_entities
end

local function pick_off_next_work(surface, player)
  local did_finish_count = false
  local chunk_queue_count = #global.chunk_queue
  if chunk_queue_count == 0 then
    -- There is no more remaining work. Start the queue.
    for chunk in surface.get_chunks() do
      if surface.is_chunk_generated(chunk) then
        global.chunk_queue[#global.chunk_queue + 1] = chunk
      end
    end
  else
    -- There is remaining work, do the next piece
    local last_chunk = global.chunk_queue[chunk_queue_count]
    table.remove(global.chunk_queue, chunk_queue_count)
    for user_name, count in pairs(count_entities_in_chunk_by_player(surface, last_chunk)) do
      increment_count_table(global.current_count, user_name, count)
    end

    -- Was this our last chunk?
    if #global.chunk_queue == 0 then
      global.last_complete_count = global.current_count
      global.current_count = {}
      did_finish_count = true
    end
  end

  return did_finish_count
end

local function on_tick(e)
  local gui_frame = mod_gui.get_frame_flow(game.players[1]).perf_frame
  if not gui_frame then
    gui_frame = mod_gui.get_frame_flow(game.players[1]).add{
      type = "frame",
      name = "perf_frame",
      style = mod_gui.frame_style,
      caption = "Infra score",
    }
    gui_frame.style.title_bottom_padding = 0
  end

  local surface = game.surfaces[1]
  local perf_frame = mod_gui.get_frame_flow(game.players[1]).perf_frame

  -- Do 10 iterations of work
  local did_change = false
  for i = 1, 10 do
    did_change = did_change or pick_off_next_work(surface, game.players[1])
  end

  if did_change then
    perf_frame.clear()

    -- Make sure each player is represented, even if 0 entities
    for _, player in pairs(game.players) do
      if not global.last_complete_count[player.name] then
        global.last_complete_count[player.name] = 0
      end
    end

    -- Sort by high score
    table.sort(
      global.last_complete_count,
      function(a, b)
        return a > b
      end
    )

    -- Add a table
    local perf_table = perf_frame.add{
      type = "table",
      name = "perf_table",
      column_count = 2,
    }
    perf_table.style.column_alignments[2] = "right"
    perf_table.style.horizontal_spacing = 8
    perf_table.style.vertical_spacing = 0

    -- Add a pair of labels for each player
    for player_name, count in pairs(global.last_complete_count) do
      perf_table.add{
        type = "label",
        caption = player_name .. ": ",
        font = "default-semibold",
      }
      local count_label = perf_table.add{
        type = "label",
        caption = util.format_number(count, true),
      }
      count_label.style.font_color = default_orange_color
    end
  elseif next(global.last_complete_count) == nil and not perf_frame.init_label then
    -- We haven't initialized yet, and haven't displayed the init label
    perf_frame.add{
      type="label",
      name="init_label",
      caption="Counting...",
    }
  end
end

script.on_event({defines.events.on_tick}, on_tick)
