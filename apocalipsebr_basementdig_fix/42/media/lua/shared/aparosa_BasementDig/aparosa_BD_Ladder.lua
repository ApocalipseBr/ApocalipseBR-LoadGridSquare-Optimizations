--[[
aparosa_BD_Ladder — 梯子（todo F34 の爬梯。利用者と決めた 2026-09-30）

■ 決めた事
  ・「地下室：梯子」のレシピは本 mod の地下室の中だけ（利用者「這個爬梯配方僅限我們的地下室的空間內..其他地方不准蓋」）。
    上の階の穴（か、穴にするマス）を指せば真下に、地下室の床のマスを指せばそのマスに梯子を置き、真上を穴にする（topZ。
    利用者 2026-10-01「也希望能直接在下一層的空間內直接透過對指定的某一格進行梯子的安裝」）。
  ・柵は使わない（利用者「爬梯能直接貼著牆壁蓋，所以不需要掛在矮牆上」）。北・西・東・南の 4 向き（利用者「四個方向都能蓋，四個方向都能登頂」）。
    壁は要らず、梯子のマスに物が無ければよい。梯子の縁は通れない（利用者 2026-10-01「梯子可以不必貼著牆壁安裝」「2 A」）。
  ・下りる: 穴の横の地面で「梯子を下りる」→ 梯子に乗る（向きは変えない。利用者「沒有必要特地轉身」）→ 下りる。上る: 上る → 地面へ出る → 立つ。

■ 仕組み
  上下の移動は原版の縄の状態（ClimbSheetRopeState・ClimbDownSheetRopeState）を使う（MP の同期も原版のまま）。
  見た目は原版の木の梯子 carpentry_02_84〜87（西・北・東・南）で、原版の絵には手を加えない。登れるのは、同じマスに置く
  本 mod の見えない縄の絵（climbSheet の旗だけ）による。原版は登れるかをマスの旗で見る（IsoGameCharacter.java 8267〜8294 行
  canClimbSheetRope、IsoWindow.isSheetRopeHere）。
  最初は原版の梯子の絵そのものに旗を足していた（Ladders mod と同じ方法）が、世界中の原版の梯子が大槌で壊せなくなった
  （原版の大槌は climbSheet の旗の物を断る。ISDestroyCursor.lua 321〜324 行）。利用者と決めた 2026-10-01「那就按照你的建議吧」で
  見えない物へ移した。梯子は原版どおり大槌・解体・バールで外せ、外すと縄と頂も外れる。
  穴には本 mod の見えない頂の絵（climbSheetTop の旗だけ。Hoppable は付けないので柵を越える動きにならない）を置く。
  原版は頂で出口に柵も窓も無いと何もしない（ClimbSheetRopeState.java 135〜224 行、Undefined）ので、その時に本 mod が
  人物を出口の地面へ移す。下りる時は本 mod の動作の後で人物を穴へ置き、原版の climbDownSheetRope を呼ぶ。
  梯子の上り下りの間は変数 AparosaLadder を真にし、梯子の動き（anims_X/Bob/aparosa_LadderClimb.x）にする
  （原版の同期の一覧へ入れる。addVariableToSyncList、LuaManager.java 7605〜7606 行）。
  専用の「乗る」「出る」の動きはまだ無い（利用者「你還是先把爬梯配方做完吧」）。下りる前・上る前の構えは本 mod の動き（aparosa_LadderMountDown・aparosa_LadderMountUp、tools/ladder_anim/mount.py）。
]]

require "aparosa_BasementDig/aparosa_BD_Rooms"
require "aparosa_BasementDig/aparosa_BD_Build"
require "aparosa_BasementDig/aparosa_BD_Check"
require "aparosa_BasementDig/aparosa_BD_Expand"
require "aparosa_BasementDig/aparosa_BD_SwitchMove"
require "aparosa_BasementDig/aparosa_BD_Sync"
require "aparosa_BasementDig/aparosa_BD_Edge"

aparosa_BD_Ladder = aparosa_BD_Ladder or {}

local log = aparosa_BD_Rooms.log

aparosa_BD_Ladder.VARIABLE = "AparosaLadder"

-- 原版 42.22 で縄の状態は梯子と一つになり、ClimbSheetRopeState・ClimbDownSheetRopeState は ClimbState・ClimbDownState へ、
-- climbSheetRope・climbDownSheetRope は climb・climbDown へ替わった（42.22.0 の IsoGameCharacter.java 8287・8304 行。
-- 縄の時は従来どおり EventClimbRope・EventClimbDownRope を出す）。42.21 には新しい名前が無いので、在る方を使う。
-- 参考: 原版 42.22.0 の ISClimbSheetRopeAction.lua（perform の climbSheetRope を climb へ書き換えた所）
aparosa_BD_Ladder.ClimbUpState = ClimbSheetRopeState or ClimbState
aparosa_BD_Ladder.ClimbDownState = ClimbDownSheetRopeState or ClimbDownState

-- 原版が梯子を上り下りできる版か（42.22 から。梯子の絵 carpentry_02_84〜87 に ladderN 等が付き、ClimbState が梯子を扱う）。
-- この版では、梯子のマスに本 mod の見えない縄、穴に見えない頂を置くと原版の梯子が壊れる（利用者と決めた 2026-10-28「1」= 案 A、
-- docs/ladder-4222-plan-zh-tw.md）: 縄があると climb が縄の道を選び、ClimbState.enter が梯子を見て ClimbRope を立てず、
-- 縄の動きの組の to_idle ですぐ待機に戻る（上れない）。頂があると上り終えた所を 0.6 上に置き落ちる（ClimbState.java 288・304 行）。
-- そこでこの版では縄と頂を置かず、上り下りは原版の梯子（Climb Ladder・Climb Down Ladder・E）に任せる。42.21 は今までのまま
aparosa_BD_Ladder.VANILLA_LADDER = ClimbState ~= nil

-- 人物が縄（か梯子）を上り下りしている状態か
function aparosa_BD_Ladder.isRopeState(state)
    local up, down = aparosa_BD_Ladder.ClimbUpState, aparosa_BD_Ladder.ClimbDownState
    return state ~= nil and ((up ~= nil and state == up.instance()) or (down ~= nil and state == down.instance()))
end

function aparosa_BD_Ladder.climbUp(p)
    if p.climbSheetRope then
        p:climbSheetRope()
    else
        p:climb()
    end
end

function aparosa_BD_Ladder.climbDown(p)
    if p.climbDownSheetRope then
        p:climbDownSheetRope()
    else
        p:climbDown()
    end
end
-- 下りる前の構えの長さ（ISBaseTimedAction の maxTime。動きは 1 秒）
aparosa_BD_Ladder.MOUNT_TIME = 30
-- 上る前の構える動作の長さ（ISBaseTimedAction の maxTime の単位）
aparosa_BD_Ladder.CLIMB_UP_TIME = 20

-- 向き → 原版の木の梯子の絵・見えない縄の絵（名前と番号）と旗・見えない頂の絵（名前と番号）と旗・出口のずれ
aparosa_BD_Ladder.DIRS = {
    N = { ropeCollide = "collideN", edge = "aparosa_ladder_edge_N", edgeId = 26599021, ladder = "carpentry_02_85", rope = "aparosa_ladder_rope_N", ropeId = 26599015, flag = "climbSheetN", top = "aparosa_ladder_top_N", topFlag = "climbSheetTopN", id = 26599011, dx = 0, dy = -1, iso = "N" },
    W = { ropeCollide = "collideW", edge = "aparosa_ladder_edge_W", edgeId = 26599022, ladder = "carpentry_02_84", rope = "aparosa_ladder_rope_W", ropeId = 26599016, flag = "climbSheetW", top = "aparosa_ladder_top_W", topFlag = "climbSheetTopW", id = 26599012, dx = -1, dy = 0, iso = "W" },
    E = { edge = "aparosa_ladder_edge_E", edgeId = 26599023, block = "aparosa_ladder_block_E", blockId = 26599019, blockFlag = "collideW", ladder = "carpentry_02_86", rope = "aparosa_ladder_rope_E", ropeId = 26599017, flag = "climbSheetE", top = "aparosa_ladder_top_E", topFlag = "climbSheetTopE", id = 26599013, dx = 1, dy = 0, iso = "E" },
    S = { edge = "aparosa_ladder_edge_S", edgeId = 26599024, block = "aparosa_ladder_block_S", blockId = 26599020, blockFlag = "collideN", ladder = "carpentry_02_87", rope = "aparosa_ladder_rope_S", ropeId = 26599018, flag = "climbSheetS", top = "aparosa_ladder_top_S", topFlag = "climbSheetTopS", id = 26599014, dx = 0, dy = 1, iso = "S" },
}

if addVariableToSyncList then
    addVariableToSyncList(aparosa_BD_Ladder.VARIABLE)
end

-- ■ 読み込み時: 見えない縄と頂の絵を作る
local function setupSprites(manager)
    for _, d in pairs(aparosa_BD_Ladder.DIRS) do
        local rope = manager:AddSprite(d.rope, d.ropeId)
        rope:setName(d.rope)
        local ropeProps = rope:getProperties()
        ropeProps:set(IsoFlagType[d.flag])
        -- 梯子の縁を通れなくする（利用者と決めた 2026-10-01「2 A」: 梯子の縁だけ塞ぎ、梯子のマスにはほかの 3 方から入れる）。
        -- 原版の縁の衝突 collideN・collideW（IsoGridSquare.java 647〜648 行、壁・柵と同じ）。マスの北と西の縁しか持てないので、
        -- 東・南の梯子は隣のマスに見えない塞ぎ（block）を置く
        if d.ropeCollide then
            ropeProps:set(IsoFlagType[d.ropeCollide])
        end
        ropeProps:CreateKeySet()
        -- 42.22 から縄の代わりに梯子のマスへ置く物（上れる旗を持たない）。北・西は梯子の縁を塞ぐ（縄の collideN・collideW と同じ）。
        -- 東・南の縁は隣のマスの塞ぐ物（block）が塞ぐので旗を持たず、本 mod の梯子の印だけ（隣に壁があると block を置かないため）
        if d.edge then
            local edge = manager:AddSprite(d.edge, d.edgeId)
            edge:setName(d.edge)
            local edgeProps = edge:getProperties()
            if d.ropeCollide then
                edgeProps:set(IsoFlagType[d.ropeCollide])
            end
            edgeProps:CreateKeySet()
        end
        if d.block then
            local block = manager:AddSprite(d.block, d.blockId)
            block:setName(d.block)
            local blockProps = block:getProperties()
            blockProps:set(IsoFlagType[d.blockFlag])
            blockProps:CreateKeySet()
        end
        local top = manager:AddSprite(d.top, d.id)
        top:setName(d.top)
        local props = top:getProperties()
        props:set(IsoFlagType[d.topFlag])
        props:CreateKeySet()
    end
end
Events.OnLoadedTileDefinitions.Add(setupSprites)

-- マスにある本 mod の梯子の頂の向き（無ければ nil）
function aparosa_BD_Ladder.topDir(sq)
    if not sq then
        return nil
    end
    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do
        local sp = objs:get(i):getSprite()
        local name = sp and sp:getName()
        for k, d in pairs(aparosa_BD_Ladder.DIRS) do
            if name == d.top then
                return k
            end
        end
    end
    return nil
end

-- マスにある本 mod の見えない縄の向き（無ければ nil）
function aparosa_BD_Ladder.ropeDir(sq)
    if not sq then
        return nil
    end
    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do
        local sp = objs:get(i):getSprite()
        local name = sp and sp:getName()
        for k, d in pairs(aparosa_BD_Ladder.DIRS) do
            if name == d.rope then
                return k
            end
        end
    end
    return nil
end

-- 本 mod の地下室の中の原版の床単縄（基礎地下室の縄など）の向き。マスの climbSheet* の旗で見る（原版の上れる判定と同じ
-- IsoWindow.isSheetRopeHere）。本 mod の地下室の外、または本 mod の梯子のマスなら nil
function aparosa_BD_Ladder.basementRopeDir(sq)
    if not sq or aparosa_BD_Ladder.ropeDir(sq) or not aparosa_BD_Expand.findRecordAt(sq:getX(), sq:getY(), sq:getZ()) then
        return nil
    end
    for k, d in pairs(aparosa_BD_Ladder.DIRS) do
        if sq:has(IsoFlagType[d.flag]) then
            return k
        end
    end
    return nil
end

-- マスの梯子の向き（無ければ nil）と、その物
function aparosa_BD_Ladder.ladderDir(sq)
    if not sq then
        return nil
    end
    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do
        local sp = objs:get(i):getSprite()
        local name = sp and sp:getName()
        for k, d in pairs(aparosa_BD_Ladder.DIRS) do
            if name == d.ladder then
                return k, objs:get(i)
            end
        end
    end
    return nil
end

-- マスに原版の木の梯子があるか（本 mod が掛けた物も、原版の家具の置き方で置いた飾りも）
function aparosa_BD_Ladder.hasLadder(sq)
    if not sq then
        return false
    end
    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do
        local sp = objs:get(i):getSprite()
        local name = sp and sp:getName()
        for _, d in pairs(aparosa_BD_Ladder.DIRS) do
            if name == d.ladder then
                return true
            end
        end
    end
    return false
end

-- マスにある名前の絵の物があるか
local function hasNamed(sq, name)
    local objs = sq and name and sq:getObjects()
    for i = 0, (objs and objs:size() or 0) - 1 do
        local sp = objs:get(i):getSprite()
        if sp and sp:getName() == name then
            return true
        end
    end
    return false
end

-- 梯子のマス below の dir の梯子が本 mod の物か。本 mod が一緒に置く物（見えない縄・縁を塞ぐ物・東南の隣の塞ぐ物・
-- 真上の見えない頂）のどれかが在れば本 mod の物と見なす（飾りに置いた原版の梯子とは分ける。搬運で外せるのも本 mod の物だけ、
-- 利用者 2026-10-28「但加回可搬屬性僅限我們的建造選單建出來的梯子」）。
function aparosa_BD_Ladder.isModLadderAt(below, dir)
    local d = dir and aparosa_BD_Ladder.DIRS[dir]
    if not below or not d then
        return false
    end
    if aparosa_BD_Ladder.ropeDir(below) == dir or hasNamed(below, d.edge) then
        return true
    end
    local cell = getCell()
    if d.block and hasNamed(cell:getGridSquare(below:getX() + d.dx, below:getY() + d.dy, below:getZ()), d.block) then
        return true
    end
    return aparosa_BD_Ladder.topDir(cell:getGridSquare(below:getX(), below:getY(), below:getZ() + 1)) == dir
end

-- 本 mod の梯子の頂の穴 hole の向き（無ければ nil）。42.21 は見えない頂で、42.22 は頂を置かないので、床の無い穴の真下に
-- 本 mod の梯子が在るかで見る
function aparosa_BD_Ladder.holeDir(hole)
    local dir = aparosa_BD_Ladder.topDir(hole)
    if dir or not hole or hole:getFloor() then
        return dir
    end
    local below = getCell():getGridSquare(hole:getX(), hole:getY(), hole:getZ() - 1)
    local ldir = aparosa_BD_Ladder.ladderDir(below)
    if ldir and aparosa_BD_Ladder.isModLadderAt(below, ldir) then
        return ldir
    end
    return nil
end

-- 上の階の穴 sq と dir の間の辺（出口へ出る辺）に壁・戸・窓・柵が無いか
local function exitEdgeFree(sq, dir)
    local cell = getCell()
    local owner, north = sq, dir == "N"
    if dir == "E" then
        owner, north = cell:getGridSquare(sq:getX() + 1, sq:getY(), sq:getZ()), false
    elseif dir == "S" then
        owner, north = cell:getGridSquare(sq:getX(), sq:getY() + 1, sq:getZ()), true
    end
    if not owner then
        return false
    end
    return owner:getWall(north) == nil and aparosa_BD_Edge.door(owner, north) == nil
        and aparosa_BD_Edge.window(owner, north) == nil and owner:getHoppable(north) == nil
end

-- カーソルのマス (x, y, cz) から、穴（梯子の頂）の階を決める（利用者と決めた 2026-10-01）。
--   ・カーソルのマスが本 mod の穴（床が無く、真下が本 mod の地下室）→ 下へ: 穴はこのマス、梯子は真下
--   ・カーソルのマスに床があり、本 mod の地下室のマス → 上へ: 梯子はこのマス、真上を穴にする
--     （利用者「如果不是洞口，那就是對目前這一層安裝通往上一層的梯子」。地下 1 階から地下 2 階へは、先に穴を掘ってから。利用者「1 可以」）
--   ・カーソルのマスに床があり、真下が本 mod の地下室（地面など）→ 下へ: このマスを穴にし、梯子は真下
-- 戻り値は穴の階。どれでもなければ nil
function aparosa_BD_Ladder.topZ(x, y, cz)
    local c = getCell():getGridSquare(x, y, cz)
    if c and not c:getFloor() and aparosa_BD_Expand.findRecordAt(x, y, cz - 1) then
        return cz
    end
    if c and c:getFloor() and aparosa_BD_Expand.findRecordAt(x, y, cz) then
        return cz + 1
    end
    if aparosa_BD_Expand.findRecordAt(x, y, cz - 1) then
        return cz
    end
    return nil
end

-- 東・南の梯子の縁を塞ぐ隣のマス（梯子のマス below の dir の隣）。その縁に壁が既に在れば要らないので nil
local function blockSquare(below, dir)
    local d = aparosa_BD_Ladder.DIRS[dir]
    if not d.block then
        return nil
    end
    local nb = getCell():getGridSquare(below:getX() + d.dx, below:getY() + d.dy, below:getZ())
    if not nb or nb:getWall(dir == "S") then
        return nil
    end
    return nb
end

-- ■ 掛けられるか。(x, y, cz) はカーソルのマス、dir は梯子を置く縁（出口の向き）。できない時は理由の翻訳キー。
-- 壁は要らない（利用者 2026-10-01「梯子可以不必貼著牆壁安裝 唯一的限制就是洞口正下方不能有東西」）。
-- 3 つ目の戻り値は記録、4 つ目は穴の階
function aparosa_BD_Ladder.validate(x, y, cz, dir)
    local d = aparosa_BD_Ladder.DIRS[dir]
    local cell = getCell()
    local z = aparosa_BD_Ladder.topZ(x, y, cz)
    local record = z and aparosa_BD_Expand.findRecordAt(x, y, z - 1)
    if not d or not record then
        return false, "IGUI_aparosa_BasementDig_Reason_LadderNotOverBasement"
    end
    local sq = cell:getGridSquare(x, y, z)
    local below = cell:getGridSquare(x, y, z - 1)
    if not sq or not below then
        return false, "IGUI_aparosa_BasementDig_Reason_NoSquare"
    end
    if not below:getFloor() then
        return false, "IGUI_aparosa_BasementDig_Reason_LadderNoFloorBelow"
    end
    -- 原版の梯子は旗を持たないので ropeReason では見えない。飾りに置いた梯子のマスにも重ねない
    if aparosa_BD_Ladder.hasLadder(below) then
        return false, "IGUI_aparosa_BasementDig_Reason_LadderAlreadyHere"
    end
    local ropeReason = aparosa_BD_Check.ropeReason(below, sq)
    if ropeReason then
        return false, ropeReason
    end
    -- 梯子のマスに物が無い事（建てる人が立っているのはよい。下から天井を開ける時はそこに立つため）
    if aparosa_BD_Check.hasBlockingObject(below, true, true) then
        return false, "IGUI_aparosa_BasementDig_Reason_LadderSpotBlocked"
    end
    if below:getWorldObjects():size() > 0 then
        return false, "IGUI_aparosa_BasementDig_Reason_LadderSpotBlocked"
    end
    if sq:getFloor() then
        -- まだ穴でない: 穴を掘るのと同じ条件
        local br = aparosa_BD_Check.blockingReason(sq, true, true)
        if br then
            return false, br
        end
        if sq:getWorldObjects():size() > 0 then
            return false, "IGUI_aparosa_BasementDig_Reason_ItemsOnHole"
        end
        if sq:getMovingObjects():size() > 0 then
            return false, "IGUI_aparosa_BasementDig_Reason_HoleOccupied"
        end
        if not aparosa_BD_Check.isNaturalFloor(sq) and not aparosa_BD_Check.hasCrowbar() then
            return false, "IGUI_aparosa_BasementDig_Reason_NeedCrowbar"
        end
    end
    -- 出口（梯子の頂から上がった人が立つ所）。理由はその場の事情ごとに分ける（2026-10-01、利用者「訊息本身的內容正確嗎？
    -- 必須清空？問題是根本沒有地面...那來的清空？應該是沒有可站立的地面不是嗎？」。それまでは 5 つの場合を全部
    -- LadderExitBlocked「梯子那一側的地面必須是空的地板」1 つで返していた。tools/ladder-reason-test.sh）
    local ex = cell:getGridSquare(x + d.dx, y + d.dy, z)
    if not ex or not ex:TreatAsSolidFloor() then
        return false, "IGUI_aparosa_BasementDig_Reason_LadderExitNoFloor"
    end
    if ex:HasStairs() then
        return false, "IGUI_aparosa_BasementDig_Reason_LadderExitStairs"
    end
    if not exitEdgeFree(sq, dir) then
        return false, "IGUI_aparosa_BasementDig_Reason_LadderExitEdge"
    end
    if ex:isSolid() or ex:isSolidTrans() then
        return false, "IGUI_aparosa_BasementDig_Reason_LadderExitObject"
    end
    return true, nil, record, z
end

-- 梯子の絵の他に要る物（頂の穴の見えない頂・梯子のマスの見えない縄・東南の縁を塞ぐ物）を置く。sq は頂の穴、below は梯子のマス
-- マスに名前の絵の物を置く（客へも送る）
local function addNamed(sq, name)
    local obj = IsoObject.new(getCell(), sq, name)
    sq:AddTileObject(obj)
    aparosa_BD_Build.sendToClients(obj)
end

-- マスから、その名前の絵の物を全部外す（客へも送る）
local function removeNamed(sq, name)
    local n = 0
    local objs = sq and name and sq:getObjects()
    for i = (objs and objs:size() or 0) - 1, 0, -1 do
        local o = objs:get(i)
        if o:getSprite() and o:getSprite():getName() == name then
            sq:transmitRemoveItemFromSquare(o)
            n = n + 1
        end
    end
    return n
end

local function installParts(sq, below, dir)
    local d = aparosa_BD_Ladder.DIRS[dir]
    local cell = getCell()
    if aparosa_BD_Ladder.VANILLA_LADDER then
        -- 42.22 から: 縄・頂を置かず（在れば外す。42.21 で建てた梯子を読んだ時もここを通る）、梯子のマスに印（北・西は縁を塞ぐ）
        removeNamed(sq, d.top)
        removeNamed(below, d.rope)
        if not hasNamed(below, d.edge) then
            addNamed(below, d.edge)
        end
    else
        addNamed(sq, d.top)
        addNamed(below, d.rope)
    end
    local nb = blockSquare(below, dir)
    if nb and not hasNamed(nb, d.block) then
        local block = IsoObject.new(cell, nb, d.block)
        nb:AddTileObject(block)
        aparosa_BD_Build.sendToClients(block)
        nb:RecalcAllWithNeighbours(true)
    end
    sq:RecalcAllWithNeighbours(true)
    below:RecalcAllWithNeighbours(true)
end

-- ■ 掛ける（サーバーと単機）
function aparosa_BD_Ladder.apply(x, y, z, dir, character)
    local before = aparosa_BD_Check.buildCharacter
    aparosa_BD_Check.buildCharacter = character or before
    local ok, reason, record, topZ = aparosa_BD_Ladder.validate(x, y, z, dir)
    aparosa_BD_Check.buildCharacter = before
    if not ok then
        log("ladder refused " .. tostring(reason))
        return false, reason
    end
    local d = aparosa_BD_Ladder.DIRS[dir]
    local cell = getCell()
    z = topZ
    local sq = cell:getGridSquare(x, y, z)
    if sq:getFloor() then
        aparosa_BD_Build.openHole(sq)
        record.holes = record.holes or {}
        table.insert(record.holes, { x = x, y = y })
    end
    local below = cell:getGridSquare(x, y, z - 1)
    local ladder = IsoObject.new(cell, below, d.ladder)
    below:AddTileObject(ladder)
    aparosa_BD_Build.sendToClients(ladder)
    installParts(sq, below, dir)
    aparosa_BD_Sync.publish()
    log(string.format("ladder placed x=%d y=%d z=%d dir=%s", x, y, z - 1, dir))
    return true
end

-- ■ 梯子に乗って下りる動作（客）
local classMade = false
local function makeClass()
    if classMade or not ISBaseTimedAction then
        return classMade
    end
    classMade = true
    aparosa_BD_LadderMountAction = ISBaseTimedAction:derive("aparosa_BD_LadderMountAction")
    function aparosa_BD_LadderMountAction:isValid()
        return aparosa_BD_Ladder.topDir(self.hole) == self.dir and aparosa_BD_Ladder.usable(self.hole)
    end
    -- 乗る前に向きを変えない（利用者 2026-09-30「往下爬的時候好像沒有必要特地轉身」）。下り始めると原版が毎回
    -- 梯子の向きへ直す（ClimbSheetRopeState・ClimbDownSheetRopeState の applyIdealDirection）。
    -- 動きは付けない。前は乗る動きの代わりに原版の Loot（屈んで拾う）を 40 当てていたが、利用者
    -- 「為什麼要特地放一個蹲下撿東西的動作？一定要接一個動作在前面？」（2026-10-01）で外した。
    -- その後「這樣少一個動作確實有點突兀」で、本 mod の構えの動きを付けた（下の start）
    -- 下りる前の構え（利用者 2026-10-01「難道不能做一個下梯子的準備攀爬動畫嗎？」）。動きは本 mod の
    -- aparosa_LadderMountDown（tools/ladder_anim/mount.py。腰を落として前へ屈み、手を床の縁の梯子の頭へ）。
    -- AnimSets/player/actions/aparosa_LadderMountDown.xml が PerformingAction で選ぶ（原版の Loot.xml と同じ形）
    -- 動きは穴に背を向けて右足を後ろの下へ伸ばす形なので、始めに梯子の向き（穴に背を向ける向き）を向く
    -- （利用者 2026-10-01「正常來說是針對梯子的方向去使用對應的從地面伸腳踏上梯子才對」。向きは 4 方とも
    -- この 1 つの動きを人物の向きで回して使う）
    function aparosa_BD_LadderMountAction:start()
        self.character:setDir(IsoDirections[aparosa_BD_Ladder.DIRS[self.dir].iso])
        self:setActionAnim("aparosa_LadderMountDown")
    end
    function aparosa_BD_LadderMountAction:perform()
        local p = self.character
        p:setVariable(aparosa_BD_Ladder.VARIABLE, true)
        p:setX(self.hole:getX() + 0.5)
        p:setY(self.hole:getY() + 0.5)
        p:setCurrent(self.hole)
        p:setDir(IsoDirections[aparosa_BD_Ladder.DIRS[self.dir].iso])
        aparosa_BD_Ladder.climbDown(p)
        ISBaseTimedAction.perform(self)
    end
    -- ■ 上る前に構える動作（客）。右クリックの「爬上梯子」は原版の縄と同じく「歩く → 上る」を並べていたが、MP で
    -- 1 回目は歩いた後の上る動作が始まらず、2 回目で上れた（2026-10-01 MP 実測: 歩く動作は終わり、上る動作の isValid も
    -- perform も呼ばれなかった）。利用者「看起來是必須讓角色有一個準備開始攀爬的預備動作」で、下りる時と同じく
    -- 構える動作を挟み、その終わりで原版の climbSheetRope を呼ぶ。原因は突き止めていない
    aparosa_BD_LadderClimbUpAction = ISBaseTimedAction:derive("aparosa_BD_LadderClimbUpAction")
    function aparosa_BD_LadderClimbUpAction:isValid()
        local sq = self.character:getCurrentSquare()
        local dir = self.ladder and aparosa_BD_Ladder.ropeDir(sq) or aparosa_BD_Ladder.basementRopeDir(sq)
        return sq == self.square and dir == self.dir and self.character:canClimbSheetRope(sq)
    end
    function aparosa_BD_LadderClimbUpAction:start()
        self.character:setDir(IsoDirections[aparosa_BD_Ladder.DIRS[self.dir].iso])
        self:setActionAnim("aparosa_LadderMountUp")
    end
    function aparosa_BD_LadderClimbUpAction:perform()
        local p = self.character
        if self.ladder then
            p:setVariable(aparosa_BD_Ladder.VARIABLE, true)
        end
        p:setDir(IsoDirections[aparosa_BD_Ladder.DIRS[self.dir].iso])
        aparosa_BD_Ladder.climbUp(p)
        ISBaseTimedAction.perform(self)
    end
    function aparosa_BD_LadderClimbUpAction:new(character, square, dir, ladder)
        local o = ISBaseTimedAction.new(self, character)
        o.square, o.dir, o.ladder = square, dir, ladder
        o.maxTime = character:isTimedActionInstant() and 1 or aparosa_BD_Ladder.CLIMB_UP_TIME
        return o
    end

    function aparosa_BD_LadderMountAction:new(character, hole, dir)
        local o = ISBaseTimedAction.new(self, character)
        o.hole, o.dir = hole, dir
        o.maxTime = character:isTimedActionInstant() and 1 or aparosa_BD_Ladder.MOUNT_TIME
        return o
    end
    return true
end
Events.OnGameStart.Add(makeClass)

-- ■ 上り始める前に、頂から出られるかを見る（客と単機）。出られなければ上らせず「上の出口が塞がれています」と出す。
-- 上り切ってから下へ戻すと、登る動きを見せた後に戻るので分かりにくかった（利用者 2026-10-01「動畫是爬完才自動又回到地下室
-- 歐不是爬之前就提示訊息」）。原版の上り方は右クリック（ISWorldObjectContextMenu.onClimbSheetRope）と、縄へ向かって歩く
-- 文脈の動作（ISContextualActions.lua の ClimbSheetRope）の 2 つで、どちらも ISClimbSheetRopeAction を並べる
-- （同 2177〜2183 行、ISContextualActions.lua 11〜16 行）ので、その isValid に足す
local climbUpPatched = false
local function patchClimbUp()
    if climbUpPatched or not ISClimbSheetRopeAction then
        return
    end
    climbUpPatched = true
    local original = ISClimbSheetRopeAction.isValid
    function ISClimbSheetRopeAction:isValid()
        if not self.down then
            local sq = self.character:getCurrentSquare()
            local dir = aparosa_BD_Ladder.ropeDir(sq)
            local up = dir and getCell():getGridSquare(sq:getX(), sq:getY(), sq:getZ() + 1)
            if up and aparosa_BD_Ladder.topDir(up) == dir and not aparosa_BD_Ladder.findExit(up, dir) then
                aparosa_BD_Check.halo(self.character, "IGUI_aparosa_BasementDig_Reason_LadderTopBlocked")
                log(string.format("ladder climb refused at %d,%d,%d: no way out at the top", sq:getX(), sq:getY(), sq:getZ()))
                return false
            end
        end
        return original(self)
    end
    -- 42.22 から梯子は原版の ISClimbLadderAction で上る（ISWorldObjectContextMenu.onClimbLadder）。原版は頂で出られないと
    -- 梯子に掴まったまま止まる（ClimbState.calculateClimbOutcome の LADDER_IDLE）ので、本 mod の梯子は上り始める前に同じく断る。
    if ISClimbLadderAction then
        local originalLadder = ISClimbLadderAction.isValid
        function ISClimbLadderAction:isValid()
            if not self.down and self.ladder then
                local below = self.ladder:getSquare()
                local dir = aparosa_BD_Ladder.ladderDir(below)
                local up = below and getCell():getGridSquare(below:getX(), below:getY(), below:getZ() + 1)
                if up and dir and aparosa_BD_Ladder.holeDir(up) == dir and not aparosa_BD_Ladder.findExit(up, dir) then
                    aparosa_BD_Check.halo(self.character, "IGUI_aparosa_BasementDig_Reason_LadderTopBlocked")
                    log(string.format("ladder climb refused at %d,%d,%d: no way out at the top", below:getX(), below:getY(), below:getZ()))
                    return false
                end
            end
            return originalLadder(self)
        end
    end
end
Events.OnGameStart.Add(patchClimbUp)

-- ■ 梯子の穴へ床単縄を掛けさせない（2026-10-03）
-- 縄の在る穴には梯子を建てさせない（validate の ropeReason）が、逆に梯子の在る 1 マスの穴の縁へ低い壁を建てると、
-- その壁に縄を結べ、1 つの穴に梯子と縄が並んだ（利用者「如果是單格洞口然後先蓋了梯子....然後再蓋低矮牆的話....
-- 結果是可以繫逃生繩的」）。原版の canAddSheetRope は壁の向きの軸（北なら N・S、西なら W・E）の縄の頂の旗だけを
-- 見る（IsoThumpable.java 1395〜1403 行）ので、梯子の頂（出口の向きの旗）と軸が違う縁では止まらない。
-- 縄の垂れるマスは原版と同じ決め方で求める（IsoWindow.addSheetRope 939〜953 行: 壁のマスに床があれば北の壁は北の隣、
-- 西の壁は西の隣、床が無ければ壁のマスそのもの）。そこが梯子の頂の穴なら、右クリックの項目を出さず、結ぶ動作も断る
function aparosa_BD_Ladder.ropeWouldHitLadder(object)
    local sq = object and object:getSquare()
    if not sq then
        return false
    end
    local north
    if instanceof(object, "IsoThumpable") or instanceof(object, "IsoWindow") then
        north = object:getNorth()
    else
        north = object:isNorthHoppable()
    end
    local target = sq
    if sq:TreatAsSolidFloor() then
        if north then
            target = getCell():getGridSquare(sq:getX(), sq:getY() - 1, sq:getZ())
        else
            target = getCell():getGridSquare(sq:getX() - 1, sq:getY(), sq:getZ())
        end
    end
    return target ~= nil and aparosa_BD_Ladder.holeDir(target) ~= nil
end

local sheetRopePatched = false
local function patchSheetRope()
    if sheetRopePatched then
        return
    end
    sheetRopePatched = true
    if ISWorldObjectContextMenu and ISWorldObjectContextMenu.doSheetRopeOptions then
        local originalOptions = ISWorldObjectContextMenu.doSheetRopeOptions
        ISWorldObjectContextMenu.doSheetRopeOptions = function(context, object, ...)
            if aparosa_BD_Ladder.ropeWouldHitLadder(object) then
                return
            end
            return originalOptions(context, object, ...)
        end
    end
    if ISAddSheetRope then
        local originalValid = ISAddSheetRope.isValid
        function ISAddSheetRope:isValid()
            if aparosa_BD_Ladder.ropeWouldHitLadder(self.window) then
                aparosa_BD_Check.halo(self.character, "IGUI_aparosa_BasementDig_Reason_LadderAlreadyHere")
                return false
            end
            return originalValid(self)
        end
    end
end
Events.OnGameStart.Add(patchSheetRope)
-- MP ではサーバーも結ぶ動作の isValid を通すので、サーバーでも包む（aparosa_BD_Basic の patchScrap と同じ）
if Events.OnServerStarted then
    Events.OnServerStarted.Add(patchSheetRope)
end

-- 長押しの E（原版の文脈の動作 ClimbSheetRope。IsoPlayer.java 5075〜5090 行で縄の旗のマスに居て向いた時）も、
-- 右クリックの「爬上梯子」と同じく構える動作を挟む（aparosa_BD_Ladder.onClimbUp）。右クリックの項目だけ替えていたので、
-- 長押しの E は原版のまま「歩く → 上る」になり、MP の中央の不具合で上らなかった（2026-10-01 利用者「長按E的部分失效了」。
-- 橋の記録で歩く・上る（canClimb=true）が繰り返され、上り始めない事を確かめた）
local contextPatched = false
local function patchContextClimb()
    if contextPatched or not (ContextualActionHandlers and ContextualActionHandlers.ClimbSheetRope) then
        return
    end
    contextPatched = true
    local original = ContextualActionHandlers.ClimbSheetRope
    ContextualActionHandlers.ClimbSheetRope = function(action, playerObj, square, down, arg3, arg4)
        if not down and square and (aparosa_BD_Ladder.ropeDir(square) or aparosa_BD_Ladder.basementRopeDir(square)) then
            return aparosa_BD_Ladder.onClimbUp(nil, square, down, playerObj:getIndex())
        end
        return original(action, playerObj, square, down, arg3, arg4)
    end
end
Events.OnGameStart.Add(patchContextClimb)

-- 梯子の頂の穴の真下に梯子と見えない縄が同じ向きで在るか（梯子を外した後に頂だけ残ると、乗った人が穴へ落ちるため）
function aparosa_BD_Ladder.usable(hole)
    local below = hole and getCell():getGridSquare(hole:getX(), hole:getY(), hole:getZ() - 1)
    local dir = aparosa_BD_Ladder.topDir(hole)
    return below ~= nil and dir ~= nil and aparosa_BD_Ladder.ladderDir(below) == dir and aparosa_BD_Ladder.ropeDir(below) == dir
end

-- 右クリックしたマスか、その 4 方の隣が梯子の頂の穴なら、穴と向き
local function findHoleNear(sq)
    if not sq then
        return nil
    end
    local dir = aparosa_BD_Ladder.topDir(sq)
    if dir then
        return sq, dir
    end
    for _, off in ipairs({ { 0, -1 }, { -1, 0 }, { 1, 0 }, { 0, 1 } }) do
        local n = getCell():getGridSquare(sq:getX() + off[1], sq:getY() + off[2], sq:getZ())
        local ndir = aparosa_BD_Ladder.topDir(n)
        if ndir then
            return n, ndir
        end
    end
    return nil
end

-- 原版の「攀爬床單繩」（ContextMenu_Climb_Sheet_Rope）は、縄の旗のマスなら縄でも梯子でも出す（ISWorldObjectContextMenuLogic.java
-- 909〜919 行）。本 mod の梯子のマスなら「梯子を上る」に名前だけ替える（利用者 2026-10-01
-- 「按右鍵顯示的還是攀爬床單繩 ... 可以改文字吧？」）。原版の翻訳は替えないので、縄では原版のまま。
-- その項目は addGetUpOption で足され、マスは引数が 2 つずれて param3 に入る（ISContextMenu.lua 1038〜1043 行）。
-- ずれ方が変わっても当たるよう、param1〜4 のうちマスの物を見る
local function renameClimbUp(context)
    local option = context:getOptionFromName(getText("ContextMenu_Climb_Sheet_Rope"))
    if not option then
        return
    end
    for _, p in ipairs({ option.param1, option.param2, option.param3, option.param4 }) do
        -- 本 mod の地下室の中の原版の縄も、名前は原版のまま構える動作を挟む。原版の MP では、縄のマスのちょうど中央に
        -- 立って右クリックで上ると、歩く動作が動かずに終わり、上る動作が走っても上り始めなかった（2026-10-01、mod 無しの
        -- 専用サーバー vanillatest で利用者が確かめた。中央から外れていれば原版が中央へ歩かせるので上れる。単機では起きない）
        if instanceof(p, "IsoGridSquare") and not aparosa_BD_Ladder.ropeDir(p) and aparosa_BD_Ladder.basementRopeDir(p) then
            if option.param1 == ISWorldObjectContextMenu.onClimbSheetRope then
                option.param1 = aparosa_BD_Ladder.onClimbUp
            end
            return
        end
        if instanceof(p, "IsoGridSquare") and aparosa_BD_Ladder.ropeDir(p) then
            option.name = getText("IGUI_aparosa_BasementLadder_ClimbUp")
            -- 原版の onClimbSheetRope（param1。立ち上がるのを待ってから呼ばれる）を、構える動作を挟む物に替える
            if option.param1 == ISWorldObjectContextMenu.onClimbSheetRope then
                option.param1 = aparosa_BD_Ladder.onClimbUp
            end
            return
        end
    end
end

-- 構える動作が使う原版の人物の関数（IsoGameCharacter.java）。原版の版が上がって名前が変わると、構える動作の終わりで
-- Lua の誤りになる。無ければ構える動作を使わず、原版の上り方（onClimbSheetRope）へ任せる
-- （利用者 2026-10-01「加吧」。本 mod の新しい版を出すまでの間に、遊ぶ人に誤りを見せないため）
aparosa_BD_Ladder.CLIMB_UP_NEEDS = { "canClimbSheetRope" }
local warnedMissing = false
function aparosa_BD_Ladder.climbUpReady(playerObj)
    for _, name in ipairs(aparosa_BD_Ladder.CLIMB_UP_NEEDS) do
        if playerObj[name] == nil then
            if not warnedMissing then
                warnedMissing = true
                log("climb up: vanilla " .. name .. " is missing; using the vanilla way to climb")
            end
            return false
        end
    end
    return true
end

-- 「爬上梯子」を選んだ時: 梯子のマスへ歩き（もう居れば歩かない）、構える動作を並べる。
-- 引数は原版の onClimbSheetRope と同じ（worldobjects, square, down, playerNum）
function aparosa_BD_Ladder.onClimbUp(worldobjects, square, down, player)
    local playerObj = getSpecificPlayer(player)
    local ladder = aparosa_BD_Ladder.ropeDir(square) ~= nil
    local dir = aparosa_BD_Ladder.ropeDir(square) or aparosa_BD_Ladder.basementRopeDir(square)
    if not playerObj or not dir or not makeClass() then
        return
    end
    if not aparosa_BD_Ladder.climbUpReady(playerObj) then
        return ISWorldObjectContextMenu.onClimbSheetRope(worldobjects, square, down, player)
    end
    local up = getCell():getGridSquare(square:getX(), square:getY(), square:getZ() + 1)
    if up and aparosa_BD_Ladder.topDir(up) == dir and not aparosa_BD_Ladder.findExit(up, dir) then
        aparosa_BD_Check.halo(playerObj, "IGUI_aparosa_BasementDig_Reason_LadderTopBlocked")
        return
    end
    if playerObj:getCurrentSquare() ~= square then
        ISTimedActionQueue.add(ISWalkToTimedAction:new(playerObj, square))
    end
    ISTimedActionQueue.add(aparosa_BD_LadderClimbUpAction:new(playerObj, square, dir, ladder))
end

local function onFillMenu(playerNum, context, worldObjects, test)
    if test or not worldObjects or not makeClass() then
        return
    end
    renameClimbUp(context)
    -- 42.22 から梯子を下りるのは原版の「Climb Down Ladder」（出口の地面で右クリック）。本 mod の項目を足すと 2 つ並ぶ
    if aparosa_BD_Ladder.VANILLA_LADDER then
        return
    end
    local player = getSpecificPlayer(playerNum)
    for _, o in ipairs(worldObjects) do
        local sq = instanceof(o, "IsoObject") and o:getSquare()
        local hole, dir = findHoleNear(sq)
        if hole and math.floor(player:getZ()) == hole:getZ() and aparosa_BD_Ladder.usable(hole) then
            context:addOption(getText("IGUI_aparosa_BasementLadder_ClimbDown"), nil, function()
                local d = aparosa_BD_Ladder.DIRS[dir]
                local exitSq = getCell():getGridSquare(hole:getX() + d.dx, hole:getY() + d.dy, hole:getZ())
                if exitSq then
                    ISTimedActionQueue.add(ISWalkToTimedAction:new(player, exitSq))
                    ISTimedActionQueue.add(aparosa_BD_LadderMountAction:new(player, hole, dir))
                end
            end)
            return
        end
    end
end
if Events.OnFillWorldObjectContextMenu then
    Events.OnFillWorldObjectContextMenu.Add(onFillMenu)
end

-- ■ 梯子の頂の穴を向いて E を長押しした時も下りる（利用者 2026-10-01「長按E上梯子往上爬可以用 但長按E下梯子往下爬不能用」）。
-- 原版の長押しの E で縄を下りるのは窓・柵の時だけ（IsoPlayer.java 5266〜5300 行）で、柵の無い梯子の頂には道が無い。
-- 長押しの長さは原版と同じ 0.5 秒（timePressedContext >= 0.5、同 5293 行）。右クリックの「爬下梯子」と同じく出口へ歩いて乗る
local HOLD_MS = 500
local interactStart, interactFired = nil, false

local function interactKey()
    return getCore() and getCore():getKey("Interact")
end

local function tryClimbDownByKey()
    -- 42.22 から長押しの E で梯子を下りるのは原版（ContextualAction の ClimbLadderDown）
    if aparosa_BD_Ladder.VANILLA_LADDER then
        return false
    end
    local player = getSpecificPlayer(0)
    local sq = player and player:getCurrentSquare()
    if not sq or player:getVehicle() or player:isClimbing() or not makeClass() then
        return false
    end
    local hole, dir = findHoleNear(sq)
    if not hole or hole == sq or not aparosa_BD_Ladder.usable(hole) or math.floor(player:getZ()) ~= hole:getZ() then
        return false
    end
    -- 人物と穴の間の辺に柵・窓・壁があれば何もしない。柵なら原版の長押しの E が越える動作を始め、越えた先の縄（梯子）を
    -- 下りる（IsoPlayer.java 5266〜5300 行）。ここでも出口への歩きと乗る動作を並べると、原版が下ろした後にも地下で
    -- 地面の出口へ歩こうとして、人物が歩き続けた（利用者 2026-10-03「翻過矮圍牆...會自動變成爬梯子進洞口...但抵達洞口之後
    -- 人物會一直自動走路...直到我強制停止」「長按 E」）
    local toHole
    for k, d in pairs(aparosa_BD_Ladder.DIRS) do
        if sq:getX() + d.dx == hole:getX() and sq:getY() + d.dy == hole:getY() then
            toHole = k
        end
    end
    if toHole and not exitEdgeFree(sq, toHole) then
        return false
    end
    -- 穴の方を向いている時だけ
    local f = player:getForwardDirection()
    local hx, hy = hole:getX() + 0.5 - player:getX(), hole:getY() + 0.5 - player:getY()
    if f:getX() * hx + f:getY() * hy <= 0 then
        return false
    end
    local d = aparosa_BD_Ladder.DIRS[dir]
    local exitSq = getCell():getGridSquare(hole:getX() + d.dx, hole:getY() + d.dy, hole:getZ())
    if not exitSq then
        return false
    end
    ISTimedActionQueue.add(ISWalkToTimedAction:new(player, exitSq))
    ISTimedActionQueue.add(aparosa_BD_LadderMountAction:new(player, hole, dir))
    return true
end

local function onKeyStartPressed(key)
    if key == interactKey() then
        interactStart, interactFired = getTimestampMs(), false
    end
end

local function onKeyKeepPressed(key)
    if key ~= interactKey() or interactFired or not interactStart then
        return
    end
    if getTimestampMs() - interactStart >= HOLD_MS then
        interactFired = true
        tryClimbDownByKey()
    end
end

local function onKeyPressed(key)
    if key == interactKey() then
        interactStart, interactFired = nil, false
    end
end

if Events.OnKeyStartPressed then
    Events.OnKeyStartPressed.Add(onKeyStartPressed)
    Events.OnKeyKeepPressed.Add(onKeyKeepPressed)
    Events.OnKeyPressed.Add(onKeyPressed)
end

-- ■ 上り下りの間の変数と、頂で地面へ出る所（自分の人物だけ）
-- 原版は頂の高さを過ぎると finishClimbing で頂のマスへ戻すが、出口に柵も窓も無いと状態を変えない（Undefined。
-- ClimbSheetRopeState.java 69〜76・203〜224 行）ので、縄を登る状態のまま頂で止まり続けた（2026-09-30 MP で確かめた）。
-- そこで、梯子の頂のマスで頂の高さに着いたら、梯子の側の地面へ移し、原版の setDefaultState（IsoGameCharacter.java 7983 行）で
-- 普段の状態へ戻す
local climbing = {}

-- 頂の穴 sq から k の向きの隣へ出られるか（床があり、塞ぐ物が無く、間の辺に壁・戸・窓・柵が無い）
local function canExitTo(sq, k)
    local d = aparosa_BD_Ladder.DIRS[k]
    local ex = getCell():getGridSquare(sq:getX() + d.dx, sq:getY() + d.dy, sq:getZ())
    if ex and ex:TreatAsSolidFloor() and not ex:isSolid() and not ex:isSolidTrans() and not ex:HasStairs()
        and exitEdgeFree(sq, k) then
        return ex
    end
    return nil
end

local function placeAt(player, target)
    player:setX(target:getX() + 0.5)
    player:setY(target:getY() + 0.5)
    player:setZ(target:getZ())
    player:setCurrent(target)
    player:setDefaultState()
    player:setVariable(aparosa_BD_Ladder.VARIABLE, false)
end

-- 頂で地面へ出す。梯子の側のマスが後から塞がれていたら（壁・柵を建てた、大きな家具を置いた）、ほかの 3 方の出られるマスへ出す。
-- どこへも出られなければ梯子の下へ戻し「出口が塞がれています」と出す（利用者と決めた 2026-10-01「那就照A吧」）。
-- 普段は上り始める前に断る（下の patchClimbUp）ので、ここで戻すのは上っている間に塞がれた時だけ。
-- 確かめずに移すと、壁を抜けたり家具の中へ入ったりした
local EXIT_ORDER = { "N", "W", "E", "S" }

-- 頂の穴 sq（梯子の向き dir）から出られるマス。梯子の側を先に見る。無ければ nil
function aparosa_BD_Ladder.findExit(sq, dir)
    local ex = canExitTo(sq, dir)
    if not ex then
        for _, k in ipairs(EXIT_ORDER) do
            ex = ex or (k ~= dir and canExitTo(sq, k)) or nil
        end
    end
    return ex
end

local function dismount(player, sq, dir)
    local ex = aparosa_BD_Ladder.findExit(sq, dir)
    if ex then
        placeAt(player, ex)
        return true
    end
    local below = getCell():getGridSquare(sq:getX(), sq:getY(), sq:getZ() - 1)
    if not below then
        return false
    end
    placeAt(player, below)
    aparosa_BD_Check.halo(player, "IGUI_aparosa_BasementDig_Reason_LadderTopBlocked")
    log(string.format("ladder top blocked at %d,%d,%d; back to the bottom", sq:getX(), sq:getY(), sq:getZ()))
    return true
end

-- 梯子で人物を梯子の真ん中へ寄せる。最初は南向き（利用者 2026-10-01「南面的梯子的爬梯動畫與梯子對不上，動畫稍微偏西」）。
-- 原版は縄を上り下りする間、毎 tick 人物をマスの中の決まった位置（idealx・idealy）へ 1/4 ずつ寄せる
-- （ClimbSheetRopeState.java の setIdealDirection・applyIdealDirection、上る時 65 行・下りる時 ClimbDownSheetRopeState.java 120 行）。
-- 南は idealx = 0.118 で、マスの西の端に近い（北 0.54・西 0.4・東 0.5417。原版の南の窓の縄に合わせた値と見る）。
-- 本 mod の梯子は南の縁の真ん中にあるので西へずれて見えた。OnPlayerUpdate は状態の処理より前に呼ばれる（IsoPlayer.java 2312 行）
-- ので、原版が 1/4 寄せた後に CENTER へ来るよう、先に T = (4 * CENTER - ideal) / 3 へ置く（毎 tick 同じ値なので震えない）
-- 西・東も同じ形で、梯子に沿う向き（y）がずれる（利用者 2026-10-04「西面的爬梯動畫裡的人物跟梯子好像也有稍微對不上」）。
-- 原版の西は idealy = 0.7（真ん中より南へ 0.2）、東は idealy = 0.3144（北へ 0.19）（ClimbSheetRopeState.java 242〜253 行、42.21.0）。
-- 北は idealx = 0.54 で真ん中との差が 0.04 なので直さない。梯子から離れる向き（南の y・西東の x）は原版のまま
local CENTER = 0.5
local ALIGN = {
    S = { axis = "x", ideal = 0.118 },
    W = { axis = "y", ideal = 0.7 },
    E = { axis = "y", ideal = 0.3144 },
}
for _, a in pairs(ALIGN) do
    a.preset = (4 * CENTER - a.ideal) / 3
end

local function alignToLadder(player, sq, topDir)
    local a = ALIGN[topDir or aparosa_BD_Ladder.ropeDir(sq) or ""]
    if not a then
        return
    end
    local state = player:getCurrentState()
    if not aparosa_BD_Ladder.isRopeState(state) then
        return
    end
    if a.axis == "x" then
        player:setX(math.floor(player:getX()) + a.preset)
    else
        player:setY(math.floor(player:getY()) + a.preset)
    end
end

-- 梯子の頂の何層手前で翻るか（todo B32、利用者の決定 2026-10-04「都按照建議」= 案 A）
local DISMOUNT_EARLY = 0.35

local function onPlayerUpdate(player)
    if not player or not player:isLocalPlayer() then
        return
    end
    local key = player:getPlayerNum()
    local sq = player:getCurrentSquare()
    local now = player:getVariableBoolean("ClimbRope")
    local topDir = aparosa_BD_Ladder.topDir(sq)
    local onLadder = sq ~= nil and (topDir ~= nil or aparosa_BD_Ladder.ropeDir(sq) ~= nil)
    if now and onLadder then
        if not player:getVariableBoolean(aparosa_BD_Ladder.VARIABLE) then
            player:setVariable(aparosa_BD_Ladder.VARIABLE, true)
        end
        climbing[key] = true
        alignToLadder(player, sq, topDir)
        -- 上っていて頂の近くに着いた（下りる時は頂から離れていくので、上り＝縄を上る状態の時だけ）。
        -- 頂の DISMOUNT_EARLY 層手前で翻る。初めは頂の階（z が上の階に着いた時）で翻っていたが、梯子の絵は 1 層の壁の高さまでなので、
        -- 最後の約 0.35 層は手が梯子より上に出て空中を上って見えた（利用者 2026-10-04「我們的爬梯動畫會不會太長？梯子都沒了我們的人還在爬」、
        -- todo B32）。手前の間は人物はまだ下の階のマス（縄のマス）に居るので、真上のマスの頂を見る
        local upState = aparosa_BD_Ladder.ClimbUpState
        if upState and player:getCurrentState() == upState.instance() then
            local top = topDir and sq or getCell():getGridSquare(sq:getX(), sq:getY(), sq:getZ() + 1)
            local dir = topDir or aparosa_BD_Ladder.topDir(top)
            if dir and not top:getFloor() and player:getZ() >= top:getZ() - DISMOUNT_EARLY then
                if dismount(player, top, dir) then
                    climbing[key] = nil
                end
            end
        end
        return
    end
    if not now and climbing[key] then
        climbing[key] = nil
        player:setVariable(aparosa_BD_Ladder.VARIABLE, false)
    end
end
Events.OnPlayerUpdate.Add(onPlayerUpdate)

-- ■ 梯子が外された時（原版の大槌・解体・バールで持ち上げ・ほかの mod）、同じマスの見えない縄と真上の見えない頂も外す（サーバーと単機）。
-- 縄が残ると見えない所で登れ、頂が残ると「縄のある穴」と見なされて穴を塞げず、乗る項目も残るため。
-- 原版の OnObjectAboutToBeRemoved（IsoGridSquare.java 5771 行の RemoveTileObject の中で呼ばれる。LuaEventManager.java 722 行）。
-- この中では外さず、次の tick で外す。MP のサーバーは「i 番目を外せ」を客へ送ってから外す（GameServer.java の RemoveItemFromMap）ので、
-- この中で同じマスの縄を外すと、縄の番号（i+1）が客で梯子が消えた後の番号とずれ、客に縄が残った（2026-10-01 MP、大槌で実測）
local pending = {}

local function flushPending()
    if #pending == 0 then
        return
    end
    local list = pending
    pending = {}
    for _, p in ipairs(list) do
        local cell = getCell()
        local sq = cell:getGridSquare(p.x, p.y, p.z)
        local up = cell:getGridSquare(p.x, p.y, p.z + 1)
        local ropes = removeNamed(sq, p.rope)
        local tops = removeNamed(up, p.top)
        -- 42.22 から縄の代わりに置く印（縁を塞ぐ物）
        ropes = ropes + removeNamed(sq, p.edge)
        if p.block then
            local d = aparosa_BD_Ladder.DIRS[p.dir]
            removeNamed(cell:getGridSquare(p.x + d.dx, p.y + d.dy, p.z), p.block)
        end
        -- バールで持ち上げると同じ梯子で 2 度呼ばれる（2 度目は外す物が無い）ので、外した時だけ書く
        if ropes + tops > 0 then
            log(string.format("ladder removed at %d,%d,%d; removed ropes=%d tops=%d", p.x, p.y, p.z, ropes, tops))
        end
    end
end
Events.OnTick.Add(flushPending)

local function onObjectAboutToBeRemoved(obj)
    if isClient() or not obj then
        return
    end
    local sq = obj:getSquare()
    local sp = obj:getSprite()
    local name = sp and sp:getName()
    local dir
    for k, d in pairs(aparosa_BD_Ladder.DIRS) do
        if name == d.ladder then
            dir = k
        end
    end
    if not sq or not dir then
        return
    end
    -- 縄か頂のどちらかが同じ向きで在る時だけ、本 mod の梯子と見なす（飾りに置いた原版の梯子では何もしない）。
    -- 縄を置く前の版で建てた梯子（頂だけ在る）もこれで頂が外れる
    -- 42.22 で建てた梯子は縄・頂の代わりに印（edge）を持つ（isModLadderAt）
    local d = aparosa_BD_Ladder.DIRS[dir]
    if not aparosa_BD_Ladder.isModLadderAt(sq, dir) then
        return
    end
    table.insert(pending, { x = sq:getX(), y = sq:getY(), z = sq:getZ(), rope = d.rope, top = d.top, edge = d.edge, block = d.block, dir = dir })
end
Events.OnObjectAboutToBeRemoved.Add(onObjectAboutToBeRemoved)

local function onCreatePlayer(_, player)
    if player then
        player:setVariable(aparosa_BD_Ladder.VARIABLE, false)
    end
end
Events.OnCreatePlayer.Add(onCreatePlayer)

-- ■ 原版の搬運で梯子を外す・付ける（todo F35。利用者 2026-10-03「A」「甚至於能透過搬運拆裝梯子的話...建築裡的「地下室：梯子
-- （使用身上的梯子）」其實就沒有存在的必要了吧？」「別忘記這邊說的僅限地下室mod的梯子」）
-- 梯子の絵 carpentry_02_84〜87 は原版で搬運できる（IsMoveAble・PickUpTool=Crowbar）。外すと onObjectAboutToBeRemoved が
-- 見えない縄・頂・塞ぐ物を外す。付け直した時、付けた所が梯子の所（真上が本 mod の穴・出口が出られる）なら、それらを置き直して
-- 登れる梯子に戻す。他の所なら飾りのまま。向きは置く時に R で回せ、外す時はバールでこじる動きと音にする（本 mod の地下室の中だけ）
local LADDER_DIR_OF = {}
for k, d in pairs(aparosa_BD_Ladder.DIRS) do
    LADDER_DIR_OF[d.ladder] = k
end
-- 原版の Facing は物の向く向き（掛かる壁の反対。ISMoveableSpriteProps.lua 2651〜2661 行 getWallForFacing）。原版の絵の定義の
-- Facing は 84・86 とも E、85・87 とも S で、4 枚が向きの組になっていない（そのため原版では回せない。258〜300 行 hasFaces・getFaces）
local FACING_OF = { W = "E", N = "S", E = "W", S = "N" }

-- below（梯子の絵のマス）に dir の梯子として付け直せるなら、頂の穴のマスを返す。付け直せない時は nil と理由の鍵
-- （理由の文は建築の窓の梯子と同じ鍵。validate の出口の調べと同じ順）
local function restoreTop(below, dir)
    local d = aparosa_BD_Ladder.DIRS[dir]
    local x, y, z = below:getX(), below:getY(), below:getZ()
    local cell = getCell()
    local top = cell:getGridSquare(x, y, z + 1)
    if not top or top:getFloor() or not aparosa_BD_Expand.findRecordAt(x, y, z) then
        return nil, "IGUI_aparosa_BasementDig_Reason_LadderNotOverBasement"
    end
    local rope = aparosa_BD_Check.ropeReason(below, top)
    if rope then
        return nil, rope
    end
    local ex = cell:getGridSquare(x + d.dx, y + d.dy, z + 1)
    if not ex or not ex:TreatAsSolidFloor() then
        return nil, "IGUI_aparosa_BasementDig_Reason_LadderExitNoFloor"
    end
    if ex:HasStairs() then
        return nil, "IGUI_aparosa_BasementDig_Reason_LadderExitStairs"
    end
    if not exitEdgeFree(top, dir) then
        return nil, "IGUI_aparosa_BasementDig_Reason_LadderExitEdge"
    end
    if ex:isSolid() or ex:isSolidTrans() then
        return nil, "IGUI_aparosa_BasementDig_Reason_LadderExitObject"
    end
    return top, nil
end

-- 原版の搬運で置いた物（サーバーと単機。置く処理は ISMoveablesAction:complete の中で OnObjectAdded を起こす:
-- ISMoveableSpriteProps.lua 2541 行。客は届いた時に AddItemToMapPacket.java 88 行でも起きるので客では何もしない）
local function onObjectAdded(obj)
    if isClient() or not obj or not obj:getSprite() then
        return
    end
    local dir = LADDER_DIR_OF[obj:getSprite():getName() or ""]
    local below = dir and obj:getSquare()
    local top = below and restoreTop(below, dir)
    if not top then
        return
    end
    installParts(top, below, dir)
    aparosa_BD_Sync.publish()
    log(string.format("ladder restored after placing at %d,%d,%d dir=%s", below:getX(), below:getY(), below:getZ(), dir))
end
Events.OnObjectAdded.Add(onObjectAdded)

-- ■ 本 mod を外して保存した世界を、本 mod を戻して読んだ時（サーバーと単機。todo B31、利用者の決定 2026-10-04「都按照建議」）。
-- 見える梯子は原版の絵（carpentry_02_84〜87）なので外しても残るが、見えない縄・頂・塞ぐ物は本 mod の絵で、外した間に保存すると
-- 絵の名の無い物（getSprite が nil）として保存され、戻しても上れなかった（段 9 ②の単機の試し、docs/evidence/remove-midgame-2026-10-04/）。
-- 梯子の絵が読まれた後の tick に、縄が無く、梯子の所として正しければ（restoreTop。搬運で付け直した時と同じ決まり）、
-- 3 つのマスの絵の無い物を外してから置き直す
local function removeSpriteless(sq)
    local objs = sq and sq:getObjects()
    for i = (objs and objs:size() or 0) - 1, 0, -1 do
        local o = objs:get(i)
        local sp = o:getSprite()
        if not sp or not sp:getName() then
            sq:transmitRemoveItemFromSquare(o)
        end
    end
end

-- MapObjects is called while Java is still integrating the chunk's objects.
-- Store coordinates only and perform mutations on a later main-thread tick.
local loadJobs, queued, waitingExits = {}, {}, {}
local firstJob, lastJob, waitingExitCount = 1, 0, 0
local LOAD_REPAIRS_PER_TICK = 8
local flushLoadJobs

local function queueLoadJob(x, y, z)
    local key = x .. "," .. y .. "," .. z
    if queued[key] then
        return
    end
    if lastJob == 0 then
        Events.OnTick.Add(flushLoadJobs)
    end
    lastJob = lastJob + 1
    loadJobs[lastJob] = { key = key, x = x, y = y, z = z }
    queued[key] = true
end

local function onLadderSpriteLoaded(object)
    local sq = object:getSquare()
    if sq and sq:getZ() < 0 then
        queueLoadJob(sq:getX(), sq:getY(), sq:getZ())
    end
end

function aparosa_BD_Ladder.hasWaitingExits()
    return waitingExitCount > 0
end

function aparosa_BD_Ladder.retryChunk(key)
    local jobs = waitingExits[key]
    if jobs then
        waitingExits[key] = nil
        waitingExitCount = waitingExitCount - 1
        for _, job in pairs(jobs) do
            queueLoadJob(job.x, job.y, job.z)
        end
    end
end

-- A legacy ladder may have loaded before its basement record was recovered.
function aparosa_BD_Ladder.retryRestoredRecord(cell, record)
    if aparosa_BD_Ladder.VANILLA_LADDER then
        return
    end
    for _, tile in ipairs(aparosa_BD_Expand.tilesOf(record)) do
        local sq = cell:getGridSquare(tile.x, tile.y, record.z)
        if aparosa_BD_Ladder.ladderDir(sq) then
            queueLoadJob(tile.x, tile.y, record.z)
        end
    end
end

local function missingExitChunk(cell, job, d)
    local x, y = job.x + d.dx, job.y + d.dy
    if not cell:getChunkForGridSquare(x, y, job.z) then
        return aparosa_BD_Build.chunkKey(x, y)
    end
    return nil
end

local function repairLoadedLadder(cell, job)
    local x, y, z = job.x, job.y, job.z
    local sq = cell:getGridSquare(x, y, z)
    local dir = aparosa_BD_Ladder.ladderDir(sq)
    if not dir then
        return
    end
    local d = aparosa_BD_Ladder.DIRS[dir]
    if aparosa_BD_Ladder.VANILLA_LADDER then
        local top = cell:getGridSquare(x, y, z + 1)
        if not top or (aparosa_BD_Ladder.ropeDir(sq) ~= dir and aparosa_BD_Ladder.topDir(top) ~= dir) then
            return
        end
        -- East and south use a collision object on the neighboring square.
        local missing = d.block and missingExitChunk(cell, job, d)
        if missing then
            return nil, missing
        end
        installParts(top, sq, dir)
        log(string.format("ladder converted for the vanilla ladder at %d,%d,%d dir=%s", x, y, z, dir))
        return true
    end
    if aparosa_BD_Ladder.ropeDir(sq) then
        return
    end
    local top, reason = restoreTop(sq, dir)
    if not top then
        if reason == "IGUI_aparosa_BasementDig_Reason_LadderExitNoFloor" then
            return nil, missingExitChunk(cell, job, d)
        end
        return
    end
    removeSpriteless(sq)
    removeSpriteless(top)
    removeSpriteless(blockSquare(sq, dir))
    installParts(top, sq, dir)
    log(string.format("ladder repaired after load at %d,%d,%d dir=%s", x, y, z, dir))
    return true
end

flushLoadJobs = function()
    local cell = getCell()
    if not cell then
        return
    end
    local changed = false
    local limit = math.min(lastJob, firstJob + LOAD_REPAIRS_PER_TICK - 1)
    for i = firstJob, limit do
        local job = loadJobs[i]
        loadJobs[i], queued[job.key] = nil, nil
        firstJob = i + 1
        local repaired, waitFor = repairLoadedLadder(cell, job)
        changed = repaired or changed
        if waitFor then
            local waiting = waitingExits[waitFor]
            if not waiting then
                waiting = {}
                waitingExits[waitFor] = waiting
                waitingExitCount = waitingExitCount + 1
            end
            waiting[job.key] = job
        end
    end
    if firstJob > lastJob then
        firstJob, lastJob = 1, 0
        Events.OnTick.Remove(flushLoadJobs)
    end
    if changed then
        aparosa_BD_Sync.publish()
    end
end

Events.OnInitGlobalModData.Add(function()
    if isClient() then
        return
    end
    Events.OnTick.Remove(flushLoadJobs)
    loadJobs, queued, waitingExits = {}, {}, {}
    firstJob, lastJob, waitingExitCount = 1, 0, 0
    local sprites = {}
    for sprite in pairs(LADDER_DIR_OF) do
        table.insert(sprites, sprite)
    end
    MapObjects.OnLoadWithSprite(sprites, onLadderSpriteLoaded, 17)
    ApocalipseBR_BasementLadderHookReady = true
end)

-- 向きの組にするか。置く時だけ（持ち上げる時に向きの組にすると、原版の持ち上げの動作が始まってすぐ止まり、梯子が外れなかった。
-- 2026-10-03 MP の橋の movepick で、ISMoveablesAction が並んですぐ消えた）。置く動作を作る時は置く所（ISMoveablesAction:new の square）、
-- カーソルの間は「放置」の形で人物の居るマスで決める。どちらも本 mod の地下室の中だけ（原版の家の壁の梯子は原版のまま）
local facesForce = nil
local function ladderFacesWanted()
    if facesForce ~= nil then
        return facesForce
    end
    if isServer() then
        return false
    end
    local p = getPlayer()
    if not p or not ISMoveableCursor or not ISMoveableCursor.mode or ISMoveableCursor.mode[p:getPlayerNum()] ~= "place" then
        return false
    end
    local sq = p:getCurrentSquare()
    return sq ~= nil and sq:getZ() < 0 and aparosa_BD_Expand.findRecordAt(sq:getX(), sq:getY(), sq:getZ()) ~= nil
end

local function inBasement(sq)
    return sq ~= nil and sq:getZ() < 0 and aparosa_BD_Expand.findRecordAt(sq:getX(), sq:getY(), sq:getZ()) ~= nil
end

local moveablePatched = false
local function patchMoveables()
    if moveablePatched or not ISMoveableSpriteProps or not ISMoveablesAction then
        return
    end
    moveablePatched = true
    -- 42.22 から原版の梯子の絵は IsMoveAble・PickUpTool を持たず、搬運できない（tools/tiledef.py の newtiledefinitions.tiles）。
    -- 本 mod の建築の窓で建てた梯子だけ、42.21 と同じく撬棍で外して置き直せるようにする（利用者 2026-10-28「mod 加回可搬屬性」
    -- 「但加回可搬屬性僅限我們的建造選單建出來的梯子」）。絵の属性は世界の全ての梯子で共通なので替えず、この表の値だけ足す。
    -- 値は原版の new が IsMoveAble の時に入れる物（ISMoveableSpriteProps.lua 42.22.0 の 142〜165 行）と同じ欄で、
    -- MoveType は 42.21 の原版で掛かる壁を要った（getWallForFacing、下の canPlaceMoveableInternal の注）ので WallObject、
    -- PickUpTool は 42.21 の Crowbar（上の注）。PickUpLevel・PickUpWeight は 42.21 の値の写しが無いので原版の既定（0・50）。
    local function makeMoveable(props)
        if not props or props.isMoveable or not aparosa_BD_Ladder.VANILLA_LADDER then
            return props
        end
        props.isMoveable = true
        props.customItem = nil
        props.type = "WallObject"
        props.pickUpTool = "Crowbar"
        props.placeTool = nil
        props.canBreak = props.spriteProps ~= nil and props.spriteProps:has("CanBreak")
        props.pickUpLevel = 0
        props.rawWeight = 50
        props.weight = props.rawWeight / 10
        props.isClosedState = false
        props.Noffset, props.Soffset, props.Woffset, props.Eoffset = 0, 0, 0, 0
        props.linkedOffset = 0
        props.linkedLoc = nil
        props.wallOverlay = false
        props.ignoreSurfaceSnap = false
        props.isGridExtensionTile = false
        props.allowDoorFrame = false
        return props
    end
    aparosa_BD_Ladder.makeMoveable = makeMoveable
    -- 外した梯子を品にする所（instanceItem → Java の Moveable.ReadFromWorldSprite）は、絵の属性に IsMoveAble が無いと品を作らない
    -- （Moveable.java 127 行、42.22.0。2026-10-28 の単機で、外す動作が終わっても梯子が残り品も出なかった）。
    -- 絵の属性は世界の全ての梯子で共通なので、本 mod の梯子を品にするこの呼び出しの間だけ足し、終わったら外す
    -- （tiledef の patch にすると 42.21 の原版の搬運の組まで作り直すため使わない。tools/make-tile-patch.py の注）。
    local originalInstanceItem = ISMoveableSpriteProps.instanceItem
    function ISMoveableSpriteProps:instanceItem(...)
        local props = self.spriteProps
        local lend = aparosa_BD_Ladder.VANILLA_LADDER and self.isMoveable and props and self.spriteName
            and LADDER_DIR_OF[self.spriteName] and not props:has("IsMoveAble")
        if not lend then
            return originalInstanceItem(self, ...)
        end
        props:set("IsMoveAble", "")
        local ok, item = pcall(originalInstanceItem, self, ...)
        props:unset("IsMoveAble")
        if not ok then
            error(item)
        end
        return item
    end
    local originalFromObject = ISMoveableSpriteProps.fromObject
    ISMoveableSpriteProps.fromObject = function(object)
        local props = originalFromObject(object)
        local dir = props and props.spriteName and LADDER_DIR_OF[props.spriteName]
        if dir and object and aparosa_BD_Ladder.isModLadderAt(object:getSquare(), dir) then
            makeMoveable(props)
        end
        return props
    end
    -- 梯子の 4 枚を向きの組にする（原版の hasFaces・getFaces・getIndexedFaces は facing と Noffset などだけを見る。258〜315 行）
    local originalNew = ISMoveableSpriteProps.new
    ISMoveableSpriteProps.new = function(sprite)
        local props = originalNew(sprite)
        local dir = props and props.spriteName and LADDER_DIR_OF[props.spriteName]
        -- 置く時（本 mod の地下室の中で置く形の時だけ。ladderFacesWanted）は、手の梯子を本 mod の梯子として扱う
        if dir and ladderFacesWanted() then
            makeMoveable(props)
        end
        if dir and props.isMoveable and props.spriteID and ladderFacesWanted() then
            props.facing = FACING_OF[dir]
            for k, d in pairs(aparosa_BD_Ladder.DIRS) do
                local id = tonumber(string.match(d.ladder, "_(%d+)$"))
                props[FACING_OF[k] .. "offset"] = id - props.spriteID
            end
        end
        return props
    end
    -- 置く動作を作る時は、置く所で向きの組にするかを決める（サーバーは人物の居る所を知らないため。置く向きは
    -- ISMoveablesAction:new が getFaces()[direction] で決める。ISMoveablesAction.lua 307〜312 行）。
    -- 包む関数の引数は原版の new と同じ名前・同じ数にする。MP では客が new の引数の名前（Prototype の locvars）で動作の欄を読んで
    -- サーバーへ送り、サーバーはその値で new を呼び直す（NetTimedAction.java 40〜50 行・142〜175 行）。最初「self, character, square,
    -- mode, ...」で包み、物・向き・品が送られずサーバーで作れず、持ち上げも置くも断られた（2026-10-03、梯子が外れなかった）
    local originalActionNew = ISMoveablesAction.new
    ISMoveablesAction.new = function(self, character, square, mode, origSpriteName, object, direction, item, moveCursor)
        local before = facesForce
        facesForce = mode == "place" and inBasement(square)
        local ok, result = pcall(originalActionNew, self, character, square, mode, origSpriteName, object, direction, item, moveCursor)
        facesForce = before
        if not ok then
            error(result)
        end
        return result
    end
    -- 外す時はバールでこじる動きと音（原版の板の取り外しと同じ。ISUnbarricadeAction.lua 46〜54 行）。原版の搬運の持ち上げは
    -- 動きが無く（ISMoveablesAction.lua 162〜190 行）、Crowbar の音は Hammer と同じ Hammering（ISMoveableDefinitions.lua 311〜312 行）
    -- 音は原版が start の setActionSound → getSoundFromTool で鳴らす（ISMoveablesAction.lua 153〜160 行、
    -- ISMoveableSpriteProps.lua 3171 行）。start の後で止めて鳴らし直すと MP で鎚の音が残り 2 つ聞こえた（2026-10-03 利用者
    -- 「我同時聽到兩種聲音」）ので、音を選ぶ所で替える
    local originalSound = ISMoveableSpriteProps.getSoundFromTool
    function ISMoveableSpriteProps:getSoundFromTool(square, character, mode)
        local obj = self.object
        if mode == "pickup" and character and obj and self.spriteName and LADDER_DIR_OF[self.spriteName]
            and inBasement(obj:getSquare()) then
            return character:playSound("BeginRemoveBarricadePlankCrowbar")
        end
        return originalSound(self, square, character, mode)
    end
    -- 地下室の中では、梯子のあるマスに 2 つ目の梯子を置かせない。原版は同じ向き（Facing）の掛かった物だけを断る
    -- （ISMoveableSpriteProps.lua 1782〜1845 行）ので、南の梯子のマスに東・北の梯子を置けた（2026-10-03 利用者「朝南面放置了梯子
    -- 卻還可以放東面跟北面的梯子」）。カーソル（canPlaceMoveable 1687 行）とサーバーの置く所（placeMoveable 2050 行）の
    -- どちらも canPlaceMoveableInternal を通るのでここで断る
    -- 縄（床単縄・本 mod の梯子の見えない縄）の掛かったマスと、その真上の穴も同じく断る（建築の窓の梯子の ropeReason と同じ。
    -- 2026-10-03 利用者「用「地下室：基礎（繩索）」…透過逃生繩爬進這格空間後，竟然四個方向都可以透過放置放梯子」）
    local function ladderBlocked(square)
        if aparosa_BD_Ladder.hasLadder(square) then
            return "IGUI_aparosa_BasementDig_Reason_LadderAlreadyHere"
        end
        local above = getCell():getGridSquare(square:getX(), square:getY(), square:getZ() + 1)
        return aparosa_BD_Check.ropeReason(square, above)
    end
    aparosa_BD_Ladder.moveableBlocked = ladderBlocked
    local originalCanPlace = ISMoveableSpriteProps.canPlaceMoveableInternal
    -- 梯子の所（restoreTop が通る所）なら、その側に壁が無くても置かせる。建築の窓の梯子は壁の無い縁にも建てられる
    -- （東・南は塞ぐ物を置く）のに、原版の搬運は掛かる壁を要る（getWallForFacing）ので、建築で建てた壁の無い梯子を外すと
    -- どの向きにも戻せなかった（2026-10-03 利用者「蓋了一個西向的不靠牆的梯子，然後用搬運把梯子移除之後卻無法放置回去」）
    function ISMoveableSpriteProps:canPlaceMoveableInternal(character, square, item, ...)
        local dir = square and self.spriteName and LADDER_DIR_OF[self.spriteName]
        if dir and inBasement(square) then
            if ladderBlocked(square) then
                return false
            end
            if square:getFloor() and restoreTop(square, dir) then
                return true
            end
        end
        return originalCanPlace(self, character, square, item, ...)
    end
    local originalStart = ISMoveablesAction.start
    function ISMoveablesAction:start()
        originalStart(self)
        local obj = self.mode == "pickup" and self.moveProps and self.moveProps.object
        local dir = obj and obj:getSprite() and LADDER_DIR_OF[obj:getSprite():getName() or ""]
        if not dir or not inBasement(obj:getSquare()) then
            return
        end
        self:setActionAnim("RemoveBarricade")
        self:setAnimVariable("RemoveBarricade", "CrowbarMid")
        self:setOverrideHandModels(self.character:getPrimaryHandItem(), nil)
    end
end
Events.OnGameStart.Add(patchMoveables)
if Events.OnServerStarted then
    Events.OnServerStarted.Add(patchMoveables)
end

-- 置く時の R で梯子の向きを回す（原版の R は置く品を替えるだけで、向きはマウスを引く・コントローラーの X だけ。
-- ISMoveableCursor.lua 702〜731 行 rotateKey・732 行 rotateWhilePlacing）。本 mod の地下室の中で梯子を置く時だけ
local cursorPatched = false
local function patchCursor()
    if cursorPatched or not ISMoveableCursor or not ISMoveableCursor.rotateKey then
        return
    end
    cursorPatched = true
    local original = ISMoveableCursor.rotateKey
    function ISMoveableCursor:rotateKey(key, joypad)
        if not joypad and ISMoveableCursor.mode[self.player] == "place" and getCore():isKey(KeybindId.ROTATE_BUILDING, key) then
            local objects = self.objectListCache or self:getInventoryObjectList()
            local o = objects and objects[self.objectIndex]
            local props = o and o.moveProps
            if props and props.spriteName and LADDER_DIR_OF[props.spriteName] and props:hasFaces() then
                self:rotateWhilePlacing()
                self.aparosaKeyFacing = true
                return
            end
        end
        return original(self, key, joypad)
    end
    -- 原版は押した所とマウスの位置で向きを決め直し、真ん中を押すと向きを捨てて壁のある向きへ寄せる（rotateMouse、
    -- ISMoveableCursor.lua 783〜815 行。snapFaceToSquare は S・E・N・W の順に探す: ISMoveableSpriteProps.lua 2614〜2627 行）。
    -- R で選んだ向きが押した時に北へ戻った（2026-10-03 利用者「我想向東或南的方向放，但按下去之後都會自動改成往北放」）ので、
    -- R で選んだ後はマウスで変えない。原版の create は置いた後に向きを捨てる（ISMoveableCursor.lua 232 行 cursorFacing = nil）ので、
    -- 予覧が北へ戻って見えた（利用者「在按下建造的那一刻，放置預覽會重置回北面」）。R で選んだ向きは create の後も残す
    local originalMouse = ISMoveableCursor.rotateMouse
    function ISMoveableCursor:rotateMouse(x, y)
        if self.aparosaKeyFacing then
            return
        end
        return originalMouse(self, x, y)
    end
    local originalCreate = ISMoveableCursor.create
    function ISMoveableCursor:create(...)
        local keep = self.aparosaKeyFacing and self.cursorFacing
        local result = originalCreate(self, ...)
        if keep then
            self.cursorFacing = keep
        end
        return result
    end
    -- 置けない時・置いても登れる梯子にならない時に、頭上へ訳を出す（原版の搬運のカーソルは訳を出さない。建築の窓の梯子と同じ鍵。
    -- 2026-10-03 利用者「顯示成紅色但卻沒顯示原因，但是從建造選單直接往西蓋梯子雖然也是紅色但會顯示原因」）。同じ所・向き・訳は 1 度だけ
    local originalValid = ISMoveableCursor.isValid
    function ISMoveableCursor:isValid(square)
        local ok = originalValid(self, square)
        local props = self.currentMoveProps
        local dir = props and props.spriteName and LADDER_DIR_OF[props.spriteName]
        if not (square and dir and ISMoveableCursor.mode[self.player] == "place" and inBasement(square)) then
            -- 梯子を置くのをやめた（別の品・別の形・地下室の外）なら、R で選んで残した向きを捨てる。残すと原版の R
            -- （cursorFacing がある間は効かない。ISMoveableCursor.lua 707 行）が他の品で効かなくなる
            if self.aparosaKeyFacing then
                self.aparosaKeyFacing = nil
                self.cursorFacing = nil
            end
            self.aparosaLadderPreview = nil
            return ok
        end
        local reason
        local blocked = aparosa_BD_Ladder.moveableBlocked and aparosa_BD_Ladder.moveableBlocked(square)
        if not self.canCreate and blocked then
            reason = blocked
        elseif not self.canCreate then
            local _, why = restoreTop(square, dir)
            reason = why or "IGUI_aparosa_BasementDig_Reason_LadderNoWall"
            local objs = square:getObjects()
            for i = 0, objs:size() - 1 do
                local p = objs:get(i):getSprite() and objs:get(i):getSprite():getProperties()
                if p and p:has("MoveType") and p:get("MoveType") == "WallObject" and p:has("Facing")
                    and p:get("Facing") == FACING_OF[dir] then
                    reason = "IGUI_aparosa_BasementDig_Reason_SwitchTaken"
                end
            end
        else
            local _, why = restoreTop(square, dir)
            reason = why
        end
        local key = string.format("%d,%d,%d,%s,%s", square:getX(), square:getY(), square:getZ(), dir, tostring(reason))
        if reason and self.aparosaReasonKey ~= key then
            aparosa_BD_Check.halo(self.character, reason)
        end
        self.aparosaReasonKey = key
        -- 予覧（render）が使う。置けて登れる梯子になる時だけ緑
        self.aparosaLadderPreview = { square = square, dir = dir, ok = self.canCreate and reason == nil }
        return ok
    end
    -- 予覧: 原版が描いた後に、本 mod の色の塗りを重ねる（isValid が決めた所・向き・可否を使い、ここでは判定しない）
    local originalRender = ISMoveableCursor.render
    function ISMoveableCursor:render(x, y, z, square)
        originalRender(self, x, y, z, square)
        local p = self.aparosaLadderPreview
        if p and square and p.square == square and aparosa_BD_CursorPatch and aparosa_BD_CursorPatch.drawMoveableLadder then
            aparosa_BD_CursorPatch.drawMoveableLadder(self.character, square, p.dir, p.ok)
        end
    end
end
Events.OnGameStart.Add(patchCursor)

return aparosa_BD_Ladder
