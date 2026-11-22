--[[
aparosa_BD_Mirror — 地下室の記録の写しを地下室のマスの modData にも置き、記録が消えた・古い時にそこから戻す（todo B33、2026-10-04）

■ なぜ
  記録（ModData の aparosa_BasementDig.digs）は原版の GameWindow.save でしか書かれない（GameWindow.java 1130 行。
  保存して閉じる・寝る・始めた時。IngameState.java 1783 行）が、地下室の床・壁は chunk と一緒に途中でも保存される。
  単機で落ちる・強制終了すると、最後の保存の後に建てた・広げた地下室は床・壁だけが残り、記録が無い・古いので部屋が外扱い
  （isOutside=true）になり、広げる・埋め戻すもできなかった（段 9 の試しで見つけた。docs/todo-ja.md B33）。
  利用者の決定 2026-10-04「B33 按照你的建議」（案 A）。

■ 作り
  - 写す: aparosa_BD_Sync.publish（記録を変えた後に必ず呼ばれる）から sync を呼ぶ。中身が変わった記録だけ（前に写した時の
    形の文字列と比べる。記録が 667 件の世界があったので全部は写さない）、版（record.mirrorVer = その時のミリ秒）を付け、
    錨と記録の全てのマス（aparosa_BD_Expand.tilesOf）の modData へ写しを置く。chunk ごとに保存の時が違うので、どのマスの
    chunk が保存されていても、そこまでの写しが残る（初めは錨だけに置き、錨の chunk が拡張より先に保存されて、戻した記録に
    拡張したマスが無かった）。マスの modData は chunk と一緒に保存され、空でない時だけ書かれる（IsoGridSquare.java 2955・9679 行）。
  - 戻す: 地下を含む chunk が読まれた時（LoadChunk、サーバーと単機）に写しを集め、OnTick で 120 tick 後に（読込の時の
    登録し直し aparosa_BD_Rooms.reapplyAll の後）同じ地下室（錨と向きが同じ）の写しのうち版の一番新しい物を取る。
    戻すまでは写さない（sync は ready まで何もしない）。戻した後に今の記録を写しの元にし（baseline。版は変えず、写しの無い
    マスへだけ置く）、その後は chunk が読まれる度に 30 tick ごとに戻す物を見る。
    錨の chunk がまだ読まれていなければ写しを保持する。錨に床が無ければ（丸ごと埋め戻した）戻さない。錨を含む記録が
      無い → 写しを記録へ足して部屋を登録する
      同じ地下室で版が古い → 写しの中身で置き換えて登録し直す（拡張の後に落ちた時）
      ほかの地下室（まとめられた等） → 戻さない
]]

require "aparosa_BasementDig/aparosa_BD_Rooms"
require "aparosa_BasementDig/aparosa_BD_Expand"
require "aparosa_BasementDig/aparosa_BD_Build"

aparosa_BD_Mirror = aparosa_BD_Mirror or {}

local KEY = "aparosa_BD_record"
local log = aparosa_BD_Rooms.log

local function copy(v)
    if type(v) ~= "table" then
        return v
    end
    local t = {}
    for k, x in pairs(v) do
        t[k] = copy(x)
    end
    return t
end

-- 記録の中身の文字列（mirrorVer は除く。鍵を並べ替えて毎回同じにする）
local function shape(v)
    if type(v) ~= "table" then
        return tostring(v)
    end
    local keys, byName = {}, {}
    for k, val in pairs(v) do
        if k ~= "mirrorVer" then
            local name = tostring(k)
            table.insert(keys, name)
            byName[name] = val
        end
    end
    table.sort(keys)
    local parts = {}
    for _, name in ipairs(keys) do
        table.insert(parts, name .. "=" .. shape(byName[name]))
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

-- 記録の錨のマスの位置と、同じ地下室かを見る鍵
local function anchorOf(record)
    if record.ax and record.ay then
        return record.ax, record.ay, record.z
    end
    local e = record.extra and record.extra[1]
    if e and e.x and e.y then
        return e.x, e.y, record.z
    end
    return nil
end

local function identity(record)
    local x, y, z = anchorOf(record)
    if not x then
        return nil
    end
    return string.format("%s:%d,%d,%d:%s", tostring(record.kind), x, y, z, tostring(record.orient))
end

-- 前に写した時の形（記録の表 → 形の文字列）。記録の表は記録が消えれば要らないので弱い表
local mirrored = setmetatable({}, { __mode = "k" })

-- 読込の後、写しから戻す前は写さない（戻す前に写すと、古い記録に新しい版が付き、マスの新しい写しが古いと見なされた。
-- 2026-10-04、拡張の後に落とした試しで拡張したマスが戻らなかった。読込の時の梯子の直しも publish を呼ぶ）
local ready = false

-- 記録の写しを錨と全てのマスへ置く。keepVer なら版を変えず、マスの写しが同じか新しければ置かない（読込の後の 1 回目）
local function writeCopies(cell, record, keepVer)
    local c = copy(record)
    local squares = {}
    local ax, ay = anchorOf(record)
    if ax then
        table.insert(squares, { x = ax, y = ay })
    end
    for _, t in ipairs(aparosa_BD_Expand.tilesOf(record)) do
        table.insert(squares, t)
    end
    for _, t in ipairs(squares) do
        local sq = cell:getGridSquare(t.x, t.y, record.z)
        if sq then
            local old = keepVer and sq:hasModData() and sq:getModData()[KEY]
            if not (type(old) == "table" and (old.mirrorVer or 0) >= (record.mirrorVer or 0)) then
                sq:getModData()[KEY] = c
            end
        end
    end
end

-- 中身が変わった記録の写しを、錨と全てのマスへ置く（サーバーと単機）
function aparosa_BD_Mirror.sync()
    if isClient() or not ready then
        return
    end
    local cell = getCell()
    if not cell then
        return
    end
    local now = getTimestampMs()
    for _, record in ipairs(aparosa_BD_Rooms.saved()) do
        local s = shape(record)
        if mirrored[record] ~= s then
            record.mirrorVer = now
            writeCopies(cell, record, false)
            mirrored[record] = s
        end
    end
end

-- Keep an unversioned legacy record at version zero so an expansion copy
-- discovered later can still supersede it.
local function baseline()
    local cell = getCell()
    if not cell then
        return
    end
    for _, record in ipairs(aparosa_BD_Rooms.saved()) do
        writeCopies(cell, record, true)
        mirrored[record] = shape(record)
    end
end

local pending, waitingAnchors = {}, {}
local waitingAnchorCount = 0
local ticksLeft
local onTick

local function keepNewest(records, id, record)
    local previous = records[id]
    if not previous or (record.mirrorVer or 0) > (previous.mirrorVer or 0) then
        records[id] = record
    end
end

local function startTimer(ticks)
    if not ticksLeft then
        ticksLeft = ticks
        Events.OnTick.Add(onTick)
    end
end

function aparosa_BD_Mirror.hasWaitingAnchors()
    return waitingAnchorCount > 0
end

function aparosa_BD_Mirror.collectChunk(chunk, minZ, key)
    local collected = false
    local waiting = key and waitingAnchors[key]
    if waiting then
        waitingAnchors[key] = nil
        waitingAnchorCount = waitingAnchorCount - 1
        collected = true
        for id, record in pairs(waiting) do
            keepNewest(pending, id, record)
        end
    end
    if minZ < 0 then
        for z = minZ, math.min(-1, chunk:getMaxLevel()) do
            for x = 0, 7 do
                for y = 0, 7 do
                    local sq = chunk:getGridSquare(x, y, z)
                    if sq and sq:hasModData() then
                        local record = sq:getModData()[KEY]
                        if type(record) == "table" and not sq:getObjects():isEmpty() then
                            local id = identity(record)
                            if id then
                                keepNewest(pending, id, record)
                                collected = true
                            end
                        end
                    end
                end
            end
        end
    end
    if ready and collected then
        startTimer(30)
    end
end

local function restorePending()
    local cell = getCell()
    if not cell then
        return
    end
    local newest = pending
    pending = {}
    local changed = {}
    for id, rec in pairs(newest) do
        local x, y, z = anchorOf(rec)
        local sq = cell:getGridSquare(x, y, z)
        if not sq and not cell:getChunkForGridSquare(x, y, z) then
            local key = aparosa_BD_Build.chunkKey(x, y)
            local waiting = waitingAnchors[key]
            if not waiting then
                waiting = {}
                waitingAnchors[key] = waiting
                waitingAnchorCount = waitingAnchorCount + 1
            end
            keepNewest(waiting, id, rec)
        elseif sq and sq:getFloor() then
            local live = aparosa_BD_Expand.findRecordAt(x, y, z)
            if not live then
                local record = copy(rec)
                table.insert(aparosa_BD_Rooms.saved(), record)
                table.insert(changed, record)
                log(string.format("record restored from square copy at %d,%d,%d variant=%s", x, y, z, tostring(record.variant)))
            elseif identity(live) == id and (live.mirrorVer or 0) < (rec.mirrorVer or 0) and shape(live) == shape(rec) then
                -- 中身は同じで版だけ新しい（版を付ける前に保存された記録が、落ちた後に読まれた時）。版だけ合わせ、登録し直さない
                -- （MP の試しで、変わっていない記録 6 つまで登録し直していた。2026-10-04）
                live.mirrorVer = rec.mirrorVer
            elseif identity(live) == id and (live.mirrorVer or 0) < (rec.mirrorVer or 0) then
                for k in pairs(copy(live)) do
                    live[k] = nil
                end
                for k, v in pairs(copy(rec)) do
                    live[k] = v
                end
                table.insert(changed, live)
                log(string.format("record updated from newer square copy at %d,%d,%d", x, y, z))
            end
        end
    end
    if #changed > 0 then
        -- 戻した部屋は前の建物が残っている事があるので、重なりの検査を飛ばす（拡張で登録し直す時と同じ。registerRects の注）
        local ok = aparosa_BD_Rooms.registerRecordsBatch(changed, function()
            return true
        end)
        log(string.format("restored records registered: %d / %d", ok, #changed))
        for _, record in ipairs(changed) do
            -- A recovered copy already has a version. Preserve it so newer
            -- copies in chunks that have yet to load can still win.
            if ready then
                writeCopies(cell, record, true)
                mirrored[record] = shape(record)
            end
            if aparosa_BD_Ladder then
                aparosa_BD_Ladder.retryRestoredRecord(cell, record)
            end
        end
        if aparosa_BD_Sync then
            aparosa_BD_Sync.publish()
        end
    end
end

onTick = function()
    ticksLeft = ticksLeft - 1
    if ticksLeft > 0 then
        return
    end
    if not getCell() then
        ticksLeft = 1
        return
    end
    ticksLeft = nil
    Events.OnTick.Remove(onTick)
    restorePending()
    if not ready then
        baseline()
        ready = true
    end
end

Events.OnInitGlobalModData.Add(function()
    if isClient() then
        return
    end
    Events.OnTick.Remove(onTick)
    pending, waitingAnchors = {}, {}
    waitingAnchorCount = 0
    mirrored = setmetatable({}, { __mode = "k" })
    ready, ticksLeft = false, nil
end)

local function startRecovery()
    if not isClient() then
        -- Run after the startup room registration, even if no chunk had copies.
        startTimer(120)
        ApocalipseBR_BasementRecoveryReady = true
    end
end
Events.OnGameStart.Add(startRecovery)
Events.OnServerStarted.Add(startRecovery)

return aparosa_BD_Mirror
