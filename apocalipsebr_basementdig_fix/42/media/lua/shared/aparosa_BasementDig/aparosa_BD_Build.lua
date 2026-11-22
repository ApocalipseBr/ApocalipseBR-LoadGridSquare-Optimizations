--[[
aparosa_BD_Build — 掘り終えた時に、地下の床・壁・階段・電灯スイッチを置き、地上に穴を開け、部屋として登録する

■ スプライト
  材料（板と釘）に合う見た目にするため、バニラの木の床・木の壁と同じスプライトを使う。
  階段だけは地図の地下室と同じ物を使う（プレイヤーが建てる木の階段は別のスプライト）。
    床        carpentry_02_56（バニラの WoodFloorLvl3 と同じ。木工 4）
    壁        walls_exterior_wooden_01_24（WallW）/ _25（WallN）/ _26（角）/ _27（柱）
              = バニラの WoodenWallLvl3 と同じ（木工 6。本 mod の要求等級 6 に合わせた）
              以前は Lvl1（_44〜_47、木工 2）で、利用者に「破れた木の壁」と言われた（2026-09-23）。
              角 _26・柱 _27 は Lvl1 の _46・_47 と同じ並びからの推定。存在は橋の sprite で確認済み
    階段（西） fixtures_stairs_01_64 / 65 / 66（stairsBW / MW / TW）
    階段（北） fixtures_stairs_01_72 / 73 / 74（stairsBN / MN / TN）
    スイッチ   lighting_indoor_01_0（attachedN）/ _1（attachedW）

■ 手順の順番に意味がある
  1. 床を先に置く: AddStairs は床の無いマスを「宙に浮いた階段」と見なし、下へ柱を足す（IsoGridSquare.AddStairs）
  2. 部屋の登録はスイッチより先: IsoLightSwitch は作られた時のマスの部屋へ自分を登録する（コンストラクタ）
  3. 電灯は作った時に消しておく: バニラの部屋の電灯と同じく、入った人が点ける（利用者と決めた 2026-09-23。placeSwitch）
]]

require "aparosa_BasementDig/aparosa_BD_Edge"
require "aparosa_BasementDig/aparosa_BD_Lights"
require "aparosa_BasementDig/aparosa_BD_Layout"
require "aparosa_BasementDig/aparosa_BD_Rooms"
require "aparosa_BasementDig/aparosa_BD_Check"
require "aparosa_BasementDig/aparosa_BD_ZExtent"

aparosa_BD_Build = aparosa_BD_Build or {}


aparosa_BD_Build.SPRITE = {
    -- 版ごとの見た目。どれもバニラのプレイヤーが建てる物と同じスプライトで、要求等級に合う物を選んだ（2026-09-23 利用者の指示）
    -- 階段は下段・中段・上段の順。W = 東西に並ぶ（向き 1・2）、N = 南北に並ぶ（向き 3・4）。
    -- バニラの entity では face S の row が「上段 → 下段」、face W の row が「上段 → 下段」の順
    variant = {
        -- 木工 6: 階段 Wood_Stairs（木工 6）、壁 WoodenWallLvl3（木工 6）、床 WoodFloorLvl3（木工 4）
        wood = {
            floor = "carpentry_02_56",
            wall = {
                W = "walls_exterior_wooden_01_24",
                N = "walls_exterior_wooden_01_25",
                NW = "walls_exterior_wooden_01_26",
                SE = "walls_exterior_wooden_01_27",
            },
            stairs = {
                W = { "carpentry_02_88", "carpentry_02_89", "carpentry_02_90" },
                N = { "carpentry_02_96", "carpentry_02_97", "carpentry_02_98" },
            },
        },
        -- 木工 3: 階段 Log_Stairs（木工 3）、壁 LogWall（等級なし）、床 WoodFloorLvl2（木工 2）
        log = {
            floor = "carpentry_02_57",
            wall = {
                W = "carpentry_02_80",
                N = "carpentry_02_81",
                NW = "carpentry_02_82",
                SE = "carpentry_02_83",
            },
            stairs = {
                W = { "crafted_02_106", "crafted_02_105", "crafted_02_104" },
                N = { "crafted_02_96", "crafted_02_97", "crafted_02_98" },
            },
        },
    },
    switch = { N = "lighting_indoor_01_0", W = "lighting_indoor_01_1" },
    -- 拡張の等級（利用者と決めた 2026-09-23: 壁は拡張する時の木工の等級に合わせ、原版の壁と同じく 4 通り）。
    -- 材料は原版の部品の合計: 木の壁 1 面 = WoodenWallLvlN（板 2・釘 4。2026-10-02 から枠 WoodenWallFrame の分は数えない。
    -- 土の壁が枠の代わり。docs/dirt-layer-plan-ja.md）、
    -- 原木の壁 1 面 = LogWall（原木 4・紐類 4）。床 1 マス = WoodFloorLvlN（板 1・釘 1）
    tier = {
        log = {
            floor = "carpentry_02_57",
            wall = { W = "carpentry_02_80", N = "carpentry_02_81", NW = "carpentry_02_82", SE = "carpentry_02_83" },
        },
        wood1 = {
            floor = "carpentry_02_58",
            wall = { W = "walls_exterior_wooden_01_44", N = "walls_exterior_wooden_01_45",
                NW = "walls_exterior_wooden_01_46", SE = "walls_exterior_wooden_01_47" },
        },
        wood2 = {
            floor = "carpentry_02_57",
            wall = { W = "walls_exterior_wooden_01_40", N = "walls_exterior_wooden_01_41",
                NW = "walls_exterior_wooden_01_42", SE = "walls_exterior_wooden_01_43" },
        },
        wood3 = {
            floor = "carpentry_02_56",
            wall = { W = "walls_exterior_wooden_01_24", N = "walls_exterior_wooden_01_25",
                NW = "walls_exterior_wooden_01_26", SE = "walls_exterior_wooden_01_27" },
        },
    },
    -- 土の壁と土の床（todo F34、埋め戻し A4。利用者と決めた 2026-09-30）。
    -- 壁は原版の土の壁 underground_01_8〜11（2026-10-03 に利用者が原版の絵の全部から見つけた）。原版ではこの 4 枚に属性が無いので、
    -- 黄褐の煉瓦 walls_exterior_house_02_96〜99 と同じ壁の属性を tiledef の patch で足す（media/aparosa_tiles.patch.tiles、
    -- mod.info の tiledef=。作り方と理由は tools/make-tile-patch.py）。Lua で属性を写す形は壁が切れず人物を隠した
    -- それまでは土の壁の絵が無いと思い、96〜99 そのものを使っていた（撮影 docs/evidence/f34-2026-09-30/wall-candidates-ingame.png）。
    -- 石積みに掛け算の色を当てる案はやめた: 壁は WallShaper.accept で頂点の色が光の色に置き換わり、setCustomColor が消える
    -- （Color.java 219〜229 行、docs/evidence/f34-2026-09-30/research-wallcolor.md）。
    -- 床は原版の「土を敷く」と同じ blends_natural_01_64（entity_floor_dirt.txt）。埋め戻しで地上の穴を戻す土の地面とも同じ
    dirt = {
        floor = "blends_natural_01_64",
        wall = { W = "underground_01_8", N = "underground_01_9",
            NW = "underground_01_10", SE = "underground_01_11" },
    },
}

-- 土の壁で広げる時の見た目（基礎地下室の拡張。aparosa_BD_Expand の tier "dirt"）
aparosa_BD_Build.SPRITE.tier.dirt = aparosa_BD_Build.SPRITE.dirt

local log = aparosa_BD_Rooms.log

-- ■ 下の階が黒く描かれるのを防ぐ（F7a。利用者と決めた 2026-09-23、案 A）
--   原版は地下の階を 2 階ずつ 1 枚の絵（FBO）に描く（-2 と -1、-4 と -3。FBORenderLevels.calculateMinLevel 249〜257 行）。
--   絵の下端は作った時の chunk の最下階で決まり（createFBOForLevel 269〜286 行）、後で下の階が増えても
--   描き直しの印を付けるだけで絵を作り直さない（FBORenderCell 1247〜1250 行、getOrCreateFBOForLevel 145〜157 行）。
--   そのため組の上側（B1・B3…）だけがある chunk に後から掘った下側（B2・B4…）が、読み直すまで黒い。
--   絵を作り直す手段は Lua に公開されていない（LuaManager 2226 行は FBORenderChunk だけ）ので、
--   組の上側の階が chunk にできた時点で下側に空のマスを 1 つ置き、絵が最初から下側まで含むようにする。
--   空のマスは保存されない（IsoGridSquare.shouldSave）ので、読み込み時（LoadChunk）にも置き直す。
--   客ではこの空のマスを置き、サーバーと単機では下の「印」を置く
--   奇数階の判定は z % 2 ~= 0。Kahlua の % は切り捨て（KahluaThread 1061〜1067 行）で -5 % 2 = -1 になり、
--   標準の Lua と違う（最初 == 1 と書いて、読み込み時に 1 つも置かれなかった。2026-09-23）
-- ■ 組の下側に残る印（F7a、2026-09-26。利用者と決めた）
--   上の「空のマス」は客の今の遊びには効くが、保存にも送信にも残らない。chunk の保存は minLevel・maxLevel を
--   物のあるマスの範囲で上書きし（IsoChunk.Save 4444〜4488 行。空のマスは IsoGridSquare.shouldSave 2955〜2957 行で外れる）、
--   サーバーは客へも同じ Save で送る（PlayerDownloadServer 232〜236 行）。そのため入り直すと客には最下階 -1 の chunk が届き、
--   入る時の読み込みで LoadChunk より前に作られる絵（GameLoadingState 360〜364 行 → FBORenderChunkManager.gameLoaded 52〜70 行）が
--   -1 を下端に固まり、後で掘った B2 が黒いまま残った（MBA の客で 7 回。-debug の Enter で絵を捨ててから掘ると描かれた）。
--   そこでサーバー（と単機）が組の下側のマスに原版の地中の塊 underground_01_0 を 1 つ置き、下側の階を保存と送信に残す。
--   原版はこの塊を「地中の塊」として持ち（IsoGridSquare.isUndergroundBlock 5291〜5298 行）、本 mod も土として扱う
--   （aparosa_BD_Check.isEarth。掘る・広げる所では removeEarth で取り除く）
-- ■ 印を見えない絵にした（todo F21、2026-09-27）
--   地中の塊は原版が黒い塊として描き、印の北西にある下側の部屋を隠した（B2 の東南の角が黒い。MP で印を外すと描かれた）。
--   印は見えない絵 invisible_01_0 に ModData の印を付けた物にした（aparosa_BD_Check.isLevelMarker）。マスに物があれば
--   保存に残るので、印の役目は変わらない。v1.3.0 までに置いた地中の塊は、読み込み時に見えない印へ置き換える（swapOldMarkers）
aparosa_BD_Build.LEVEL_MARKER = aparosa_BD_Check.LEVEL_MARKER
aparosa_BD_Build.OLD_LEVEL_MARKER = "underground_01_0"

local function hasSavedLevel(chunk, level)
    for ly = 0, 7 do
        for lx = 0, 7 do
            local sq = chunk:getGridSquare(lx, ly, level)
            if sq and sq:getObjects():size() > 0 then
                return true
            end
        end
    end
    return false
end

local function placeLevelMarker(chunk, x, y, below)
    if hasSavedLevel(chunk, below) then
        return
    end
    local cell = getCell()
    local sq = cell:getGridSquare(x, y, below) or cell:createNewGridSquare(x, y, below, true)
    if not sq then
        return
    end
    local obj = IsoObject.new(cell, sq, aparosa_BD_Build.LEVEL_MARKER)
    obj:getModData()[aparosa_BD_Check.LEVEL_MARKER_KEY] = true
    sq:AddTileObject(obj)
    if isServer() then
        obj:transmitCompleteItemToClients()
    end
    log(string.format("level marker placed at (%d,%d,%d)", x, y, below))
end

local function reservePairBottom(chunk, x, y, z)
    if not chunk or z >= 0 or z % 2 == 0 then
        return
    end
    local below = z - 1
    if below < aparosa_BD_Check.BOTTOM then
        return
    end
    if not isClient() then
        placeLevelMarker(chunk, x, y, below)
        return
    end
    if chunk:getMinLevel() <= below then
        return
    end
    getCell():createNewGridSquare(x, y, below, true)
    log(string.format("pair bottom reserved at (%d,%d,%d)", x, y, below))
end

-- (x, y) と周りの 8 マスが載る chunk すべてで、組の下側を空けておく。
-- 原版は床や階段を置く時に周りの 8 マスを作る（IsoGridSquare 5229 行・5302 行の EnsureSurroundNotNull。
-- ISBuildIsoEntity.lua 146 行も同じ）。隣の chunk にもこの階ができるので、自分のマスの chunk だけでは足りない
-- （2026-09-23 実測: B7 の 4 chunk のうち 1 つしか空のマスが置かれず、残り 3 chunk の B8 が黒かった）
local function reservePairBottomAround(x, y, z)
    local cell = getCell()
    local seen = {}
    for dy = -1, 1 do
        for dx = -1, 1 do
            local chunk = cell:getChunkForGridSquare(x + dx, y + dy, z)
            if chunk and not seen[chunk] then
                seen[chunk] = true
                reservePairBottom(chunk, x + dx, y + dy, z)
            end
        end
    end
end

-- ■ 新しい地下のマスの光を計算し直させる（F7a。利用者と決めた 2026-09-24）
--   原版は光の情報が無いマスを描かない（FBORenderCell.prepareChunkForUpdating 3957〜3990 行）。
--   chunk に新しい階ができても chunk 全体の lightCheck は立たない（IsoChunk.setMinMaxLevel）ので、
--   新しい階の光の計算が遅れて黒く見える、という候補への手当て。原因は未確定で、効き目も確かめていない
--   （B14 で黒い塊が出ず、橋の relight で試せなかった）。「後で計算する」印を付けるだけなので、
--   床や壁を置いた後の光の更新で計算される。カーソルの経路（毎フレーム呼ばれる）には付けない
local function relightAround(x, y, z)
    if isServer() or z >= 0 then
        return
    end
    local cell = getCell()
    local seen = {}
    for dy = -1, 1 do
        for dx = -1, 1 do
            local chunk = cell:getChunkForGridSquare(x + dx, y + dy, z)
            if chunk and not seen[chunk] then
                seen[chunk] = true
                -- その階だけにする（2026-09-26）。前は全ての階（地上の家の 2 階や屋根まで）を計算し直させていた。
                -- OnObjectAdded から地下に物が 1 つ置かれる度に呼ばれるので、無駄が大きかった
                -- （IsoChunk.checkLightingLater_AllPlayers_OneLevel 354〜360 行、LightingJNI.updateChunk 616〜620 行は印の立った階だけ計算する）
                chunk:checkLightingLater_AllPlayers_OneLevel(z)
            end
        end
    end
end

local function squareAt(x, y, z)
    local cell = getCell()
    local sq = cell:getGridSquare(x, y, z)
    if not sq then
        sq = cell:createNewGridSquare(x, y, z, true)
    end
    if sq then
        reservePairBottomAround(x, y, z)
        relightAround(x, y, z)
        -- 地下の階の階段・スイッチを描く幅に入れる（単機。次の tick に 1 回。aparosa_BD_ZExtent の頭）
        aparosa_BD_ZExtent.request()
    end
    return sq
end

-- 読み込んだ chunk の最下階が組の上側なら、下側に空のマスを置く（地図の B1 の下や、前に掘った B3 の下も含む）。
-- LoadChunk は IsoChunk.doLoadGridsquare の最後に呼ばれ（IsoChunk 3998 行）、その chunk を描く前に届く
-- サーバーと単機: 読み込んだ chunk で、床のある奇数の地下階ごとに、下の階へ印を置く（保存の前の古い地下室にも効かせる）。
-- 最下階の奇偶では決めない。サーバーでは隣の chunk の読み込みなどで下の階に空のマスが先にでき（IsoChunk 2691〜2750 行）、
-- 最下階が偶数に見えて飛ばしてしまった（2026-09-26 実測: 直す前に掘った B1 の chunk (1348,1180) だけ印が置かれなかった）
-- v1.3.0 までの印（地中の塊）を見えない印へ置き換える。組の下側の階（偶数）で、物が地中の塊 1 つだけ、
-- 真上のマスに床がある所だけを本 mod の印と見る（印は床のあるマスの真下に置いた）
local function swapOldMarkers(chunk, minZ)
    for z = minZ, -2 do
        if z % 2 == 0 then
            for ly = 0, 7 do
                for lx = 0, 7 do
                    local sq = chunk:getGridSquare(lx, ly, z)
                    local objs = sq and sq:getObjects()
                    local above = sq and chunk:getGridSquare(lx, ly, z + 1)
                    if objs and objs:size() == 1 and above and above:getFloor() then
                        local old = objs:get(0)
                        local sp = old:getSprite()
                        if sp and sp:getName() == aparosa_BD_Build.OLD_LEVEL_MARKER then
                            sq:transmitRemoveItemFromSquare(old)
                            local obj = IsoObject.new(getCell(), sq, aparosa_BD_Build.LEVEL_MARKER)
                            obj:getModData()[aparosa_BD_Check.LEVEL_MARKER_KEY] = true
                            sq:AddTileObject(obj)
                            if isServer() then
                                obj:transmitCompleteItemToClients()
                            end
                            log(string.format("level marker swapped at (%d,%d,%d)", sq:getX(), sq:getY(), z))
                        end
                    end
                end
            end
        end
    end
end

local function markLoadedChunk(chunk, minZ)
    swapOldMarkers(chunk, minZ)
    for z = minZ, -1 do
        if z % 2 ~= 0 and z - 1 >= aparosa_BD_Check.BOTTOM then
            local done = false
            for ly = 0, 7 do
                for lx = 0, 7 do
                    local sq = not done and chunk:getGridSquare(lx, ly, z)
                    if sq and sq:getFloor() then
                        placeLevelMarker(chunk, sq:getX(), sq:getY(), z - 1)
                        done = true
                    end
                end
            end
        end
    end
end

-- B42 chunks contain 8 x 8 squares. Only resolve a chunk's world key when
-- stalled recovery work is waiting for a chunk to load.
function aparosa_BD_Build.chunkKey(x, y)
    return math.floor(x / 8) .. "," .. math.floor(y / 8)
end

local function loadedChunkKey(chunk, minZ)
    local square = chunk:getGridSquare(0, 0, 0)
    if not square then
        for z = minZ, chunk:getMaxLevel() do
            for x = 0, 7 do
                for y = 0, 7 do
                    square = chunk:getGridSquare(x, y, z)
                    if square then
                        return aparosa_BD_Build.chunkKey(square:getX(), square:getY())
                    end
                end
            end
        end
        return nil
    end
    return aparosa_BD_Build.chunkKey(square:getX(), square:getY())
end

local function onLoadChunk(chunk)
    if isClient() then
        return
    end
    local minZ = chunk:getMinLevel()
    local mirror, ladder = aparosa_BD_Mirror, aparosa_BD_Ladder
    local key
    if (mirror and mirror.hasWaitingAnchors()) or (ladder and ladder.hasWaitingExits()) then
        key = loadedChunkKey(chunk, minZ)
    end
    if mirror then
        mirror.collectChunk(chunk, minZ, key)
    end
    if ladder and key then
        ladder.retryChunk(key)
    end
    markLoadedChunk(chunk, minZ)
end
Events.LoadChunk.Add(onLoadChunk)

-- 客の OnObjectAdded（地下の物が届く度に予約と光の計算し直し。2026-09-24 に足した）は 2026-09-26 に外した。
-- サーバーの印で下の階が chunk の送信に入るので、客で何もしなくても、同じ遊びの中で B1 を掘ってすぐ下を掘った B2 が
-- 描かれ、灯を消すと 0.384・点けると 0.898 になった（MP の Air の客、workshop/shots/obs/cleanup-p2-no-relight-drawn.png）。
-- 地下に物が 1 つ届く度に周りの chunk を見て光を計算し直させる手間が無くなった

-- 原版の建築カーソルは、描くたびに目標と周り 8 マスを作り、その下の階も chunk の最下階まで作る
-- （ISBuildIsoEntity.lua 70〜71 行の render → ensureSquaresExist 111〜147 行）。カーソルを動かすだけで
-- 隣の chunk に新しい階ができ、本 mod の squareAt より先に絵が作られることがあるので、そこも包む。
-- ISBuildIsoEntity は server/ にあり shared/ の読込時にはまだ無いので、ゲーム開始時に包む
local ensureWrapped = false
local function wrapEnsureSquareExists()
    if ensureWrapped or not ISBuildIsoEntity or not ISBuildIsoEntity.ensureSquareExists2 then
        return
    end
    ensureWrapped = true
    local original = ISBuildIsoEntity.ensureSquareExists2
    ISBuildIsoEntity.ensureSquareExists2 = function(self, x, y, z)
        local square = original(self, x, y, z)
        if z < 0 then
            reservePairBottomAround(x, y, z)
        end
        return square
    end
end
Events.OnGameStart.Add(wrapEnsureSquareExists)

-- 地中タイル（underground_01）があれば取り除く
local function removeEarth(sq)
    local objs = sq:getObjects()
    for i = objs:size() - 1, 0, -1 do
        local obj = objs:get(i)
        if aparosa_BD_Check.isEarth(obj) then
            sq:transmitRemoveItemFromSquare(obj)
        end
    end
end

-- マスの西・北の辺に載っている物（壁・柵・戸・窓・掛けた物）。穴を開けても残す。
-- 西の壁はそのマスの物として持つ（北も同じ）ので、建物や柵の東・南の外側に接して掘ると、穴のマスがその壁を持っている。
-- aparosa_BD_Check の hasBlockingObject は、範囲の西端の列の西の壁・北端の行の北の壁を「外縁に沿うだけ」として止めない。
-- なのに穴を開ける時に全部取り除いていたので、建物の壁や木の柵が消えた（todo B16。2026-09-25 に建物の壁、
-- 2026-09-26 に木の柵。利用者が MacBook Pro で見つけた）。辺の物の拾い方は原版の IsoGridSquare の getter
-- （getWall は sprite の cutN・cutW を見る。IsoGridSquare.java 5020 行付近、42.20.4）。止めない物と同じ物だけが残る
-- 戸と窓は aparosa_BD_Edge で探す（42.21 で原版の getDoor(boolean)・getWindow(boolean) が無くなったため、2026-09-28）
local function edgeObjects(sq)
    local keep = {}
    local function add(obj)
        if obj then
            keep[obj] = true
        end
    end
    for _, north in ipairs({ true, false }) do
        add(sq:getWall(north))
        add(aparosa_BD_Edge.door(sq, north))
        add(aparosa_BD_Edge.window(sq, north))
        add(sq:getHoppable(north))
        add(sq:getGarageDoor(north))
    end
    add(sq:getWallNW())
    -- 残した壁に掛けた物（絵・スイッチなど）も残す
    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        local props = obj:getSprite() and obj:getSprite():getProperties()
        if props and (props:has(IsoFlagType.attachedW) or props:has(IsoFlagType.attachedN)) then
            keep[obj] = true
        end
    end
    return keep
end

-- 地上の穴: そのマスの物（床・草の重ね絵など）を取り除く。西・北の辺の物は残す（edgeObjects）。
-- 利用者の決定（2026-09-23）: はがした床は返さない（掘って壊す扱い）
local function openHole(sq)
    local keep = edgeObjects(sq)
    local objs = sq:getObjects()
    for i = objs:size() - 1, 0, -1 do
        local obj = objs:get(i)
        if not keep[obj] then
            sq:transmitRemoveItemFromSquare(obj)
        end
    end
    sq:RecalcAllWithNeighbours(true)
end

-- 版ごとの見た目。記録に無い古い版名は wood として扱う
function aparosa_BD_Build.look(variant)
    return aparosa_BD_Build.SPRITE.variant[variant] or aparosa_BD_Build.SPRITE.variant.wood
end

-- look は aparosa_BD_Build.look(variant) か SPRITE.tier[名前]（床と壁の表）
-- 置いた物を客へ送る。AddTileObject・AddStairs・AddSpecialObject は自分の側に足すだけで送らない
-- （IsoGridSquare.java 5300〜5345・6258〜6298・6305〜6335、42.20.4）。送るのは transmitCompleteItemToClients で、
-- サーバーの時だけ AddItemToMap を送り、単機では何もしない（IsoObject.java 4559〜4567）。BuildingCraft も置いた後に同じ物を呼ぶ。
-- マルチプレイで、客に床だけが見えて壁・階段・スイッチが無く、部屋の外の床の無いマスへ出て下へ落ちた（2026-09-24、利用者が試した）
local function sendToClients(obj)
    if obj then
        obj:transmitCompleteItemToClients()
    end
end
aparosa_BD_Build.sendToClients = sendToClients

-- 電灯スイッチの入り切りを決めてから客へ送る（todo B20 の V2）。
-- IsoLightSwitch.setActive(v, false, true) は状態が変わると syncIsoObject を送る（IsoLightSwitch.java 499〜503 行）。
-- 物を足した packet より先に届くと、客は番号で物を探す（GameClient.java 1645〜1646 行）ので別の物に当たるか捨てられる。
-- サーバーでは、状態だけを先に決め（setActiveBoolOnly = true、sync を送らない）、物を送った後で部屋の灯を切り替える
-- （switchLight は部屋の lightsActive と MetaGrid の packet、IsoLightSwitch.java 513〜530 行）。
-- 単機は送る物が無いので今まで通り setActive で灯まで切り替える
function aparosa_BD_Build.setSwitchThenSend(sw, active)
    if isServer() then
        sw:setActive(active, true, true)
        sendToClients(sw)
        sw:switchLight(active)
    else
        -- 引数: active, setActiveBoolOnly, ignoreSwitchCheck（IsoLightSwitch.setActive）
        sw:setActive(active, false, true)
        sendToClients(sw)
    end
    -- 入り切りを本 mod の記録にも残す（起こし直した時に戻すため。todo B23、aparosa_BD_Lights）
    aparosa_BD_Lights.remember(sw)
end

local function placeWallLook(sq, kind, look)
    local obj = IsoObject.new(getCell(), sq, look.wall[kind])
    sq:AddTileObject(obj)
    sendToClients(obj)
end

-- 土の壁を 1 枚置く（kind = W / N / NW / SE）
local function placeDirtWall(sq, kind)
    local obj = IsoObject.new(getCell(), sq, aparosa_BD_Build.SPRITE.dirt.wall[kind])
    sq:AddTileObject(obj)
    sendToClients(obj)
    return obj
end

local function placeWall(sq, kind, variant)
    local obj = IsoObject.new(getCell(), sq, aparosa_BD_Build.look(variant).wall[kind])
    sq:AddTileObject(obj)
    sendToClients(obj)
end

-- 拡張（aparosa_BD_Expand）からも使う
aparosa_BD_Build.squareAt = squareAt
aparosa_BD_Build.removeEarth = removeEarth
aparosa_BD_Build.openHole = openHole
aparosa_BD_Build.placeWall = placeWall
aparosa_BD_Build.placeWallLook = placeWallLook
aparosa_BD_Build.placeDirtWall = placeDirtWall

local function placeStairs(L, s, variant, level)
    local sq = squareAt(s.x, s.y, level)
    local set = aparosa_BD_Build.look(variant).stairs
    local names = L.north and set.N or set.W
    -- level は 0〜2、Lua の配列は 1 から
    local t = sq:AddStairs(L.north, s.level, names[s.level + 1], nil, {})
    t:setName("Basement Stairs")
    t:setIsStairs(true)
    t:setCanBarricade(false)
    -- 地下室の唯一の出入口なので、解体で壊せないようにする
    t:setIsDismantable(false)
    -- 名前・旗を決めてから送る（客も同じ状態で持つように）
    sendToClients(t)
    sq:RecalcAllWithNeighbours(true)
end

-- (x, y, level) の wall（"N" か "W"）の辺に電灯スイッチを置く。基礎地下室のスイッチを付けるレシピ（aparosa_BD_Basic）も使う
local function placeSwitchAt(x, y, level, wall)
    local sq = getCell():getGridSquare(x, y, level)
    if not sq then
        return nil
    end
    -- 電灯スイッチが作れなくても、地下室そのものは使えるようにする
    if not IsoLightSwitch or not IsoLightSwitch.new then
        log("IsoLightSwitch is missing; skipping the light switch")
        return
    end
    local sw = IsoLightSwitch.new(getCell(), sq, getSprite(aparosa_BD_Build.SPRITE.switch[wall]), sq:getRoomID())
    sw:addLightSourceFromSprite()
    sq:AddSpecialObject(sw)
    -- 作った時は消しておく。バニラの部屋の電灯と同じく、入った人が点ける（利用者と決めた 2026-09-23）
    aparosa_BD_Build.setSwitchThenSend(sw, false)
    log(string.format("switch placed x=%d y=%d activated=%s", x, y, tostring(sw:isActivated())))
    return sw
end
aparosa_BD_Build.placeSwitchAt = placeSwitchAt

local function placeSwitch(L, level)
    placeSwitchAt(L.switch.x, L.switch.y, level, L.switch.wall)
end

-- 掘削を反映する。成功したら true
-- variant = "wood"（木工 6 の版）か "log"（木工 3 の原木の版）。見た目は aparosa_BD_Build.SPRITE.variant
-- fromZ = 掘り始めた階（地上 0、地下室の床なら -1 など）。地下室は一つ下の fromZ - 1 に作り、穴は fromZ に開ける
-- 4x2 を、接する 1 マスの穴の地下室（hosts）へ足して建てる（利用者 2026-10-01「我還是希望4x2的木牆、原木牆地下室跟1格的地洞可以直接
-- 貼著蓋，但開關必須先移動的那個規則不能變」。スイッチの方は 2026-10-03 に「按照建議」で床へ落とすに変えた。todo F35）。原版は接する別の建物を登録させない（BuildingRoomsEditor.canAddRoomRectangle）ので、
-- 新しい部屋にせず、部屋の 8 マスを 1 マスずつ拡張（aparosa_BD_Expand.apply。上から = fromAbove。外す壁の梯子の検査と、スイッチを落とすのも通る）で
-- 足し、終わってから 8 マスを extra から joined の配置へ移す（rectsOf が配置からマスを数える）。木の 4x2 の床・壁は拡張の等級 wood3、
-- 原木は log と同じ絵（aparosa_BD_Build.SPRITE）
local function applyMerged(L, variant, fromZ, hosts)
    local z = fromZ - 1
    -- 貼る時の等級は種類の登録（aparosa_BD_Types.registerVariant の mergeTier）。知らない種類は木と同じ wood3
    local def = aparosa_BD_Types and aparosa_BD_Types.variant(variant)
    local tier = def and def.mergeTier or "wood3"
    local remaining = {}
    for _, p in ipairs(aparosa_BD_Layout.roomSquares(L)) do
        table.insert(remaining, p)
    end
    local host = nil
    local function neighbourRecord(p, diagonal)
        local dirs = diagonal and { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } or { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
        for _, d in ipairs(dirs) do
            local rec = aparosa_BD_Expand.findRecordAt(p.x + d[1], p.y + d[2], z)
            if rec and (rec == host or (not host and hosts[rec])) then
                return rec
            end
        end
        return nil
    end
    while #remaining > 0 do
        local pick, rec = nil, nil
        for i, p in ipairs(remaining) do
            rec = neighbourRecord(p, false)
            if rec then
                pick = i
                break
            end
        end
        if not pick and not host then
            for i, p in ipairs(remaining) do
                rec = neighbourRecord(p, true)
                if rec then
                    pick = i
                    break
                end
            end
        end
        if not pick then
            log("build merged: no square next to the basement (stuck)")
            return false
        end
        local p = table.remove(remaining, pick)
        if not aparosa_BD_Expand.apply(p.x, p.y, z, tier, true, rec) then
            log(string.format("build merged: expand failed at %d,%d,%d", p.x, p.y, z))
            return false
        end
        host = aparosa_BD_Expand.findRecordAt(p.x, p.y, z)
    end
    -- 8 マスを extra から外し、4x2 の配置として joined へ入れる
    local own = {}
    for _, p in ipairs(aparosa_BD_Layout.roomSquares(L)) do
        own[p.x .. "," .. p.y] = true
    end
    for i = #(host.extra or {}), 1, -1 do
        local t = host.extra[i]
        if own[t.x .. "," .. t.y] then
            table.remove(host.extra, i)
        end
    end
    host.joined = host.joined or {}
    table.insert(host.joined, { ax = L.ax, ay = L.ay, orient = L.orient, variant = variant })
    for _, h in ipairs(L.holes) do
        local sq = getCell():getGridSquare(h.x, h.y, fromZ)
        if sq then
            openHole(sq)
        end
    end
    for _, s in ipairs(L.stairs) do
        placeStairs(L, s, variant, z)
    end
    -- スイッチ: 4x2 は電網に繋いで建つ。足す先が繋いでいない（土の版）なら、普通の名前で登録し直して繋ぐ（applySwitch と同じ。
    -- スイッチは置く時のマスの部屋へ入るので、部屋を先に替える）。決まった壁が外れていれば、部屋の別の北・西の壁に付ける
    if host.noGrid then
        host.noGrid = nil
        if not aparosa_BD_Rooms.renameRecord(host) then
            host.noGrid = true
            log("build merged: grid connect failed")
        end
    end
    local sw = L.switch
    local placed = false
    local function tryAt(x, y, wall)
        local sq = getCell():getGridSquare(x, y, z)
        if sq and aparosa_BD_SwitchMove.hasWall(sq, wall) then
            placeSwitchAt(x, y, z, wall)
            return true
        end
        return false
    end
    placed = tryAt(sw.x, sw.y, sw.wall)
    if not placed then
        for _, p in ipairs(aparosa_BD_Layout.roomSquares(L)) do
            if tryAt(p.x, p.y, "N") or tryAt(p.x, p.y, "W") then
                placed = true
                break
            end
        end
    end
    if not placed then
        log("build merged: no wall for the light switch")
    end
    aparosa_BD_Sync.publish()
    log(string.format("build done merged ax=%d ay=%d z=%d orient=%d variant=%s into ax=%s ay=%s", L.ax, L.ay, z, L.orient,
        variant, tostring(host.ax), tostring(host.ay)))
    return true
end

function aparosa_BD_Build.apply(L, variant, fromZ)
    variant = variant or "wood"
    fromZ = fromZ or 0
    local z = fromZ - 1
    -- 接する 1 マスの穴の地下室が在れば、そこへ足して建てる
    -- PZ の Lua（Kahlua）には next が無い（2026-10-01、next(hosts) で「tried to call nil」）。pairs で数える
    local hosts = {}
    if aparosa_BD_Check.belowReason(L, z, true, hosts) == nil then
        for _ in pairs(hosts) do
            return applyMerged(L, variant, fromZ, hosts)
        end
    end
    for _, p in ipairs(aparosa_BD_Layout.roomSquares(L)) do
        local sq = squareAt(p.x, p.y, z)
        removeEarth(sq)
        sq:addFloor(aparosa_BD_Build.look(variant).floor)
    end
    for _, w in ipairs(L.walls) do
        local sq = squareAt(w.x, w.y, z)
        removeEarth(sq)
        placeWall(sq, w.kind, variant)
    end
    for _, h in ipairs(L.holes) do
        local sq = getCell():getGridSquare(h.x, h.y, fromZ)
        if sq then
            openHole(sq)
        end
    end
    for _, s in ipairs(L.stairs) do
        placeStairs(L, s, variant, z)
    end
    if not aparosa_BD_Rooms.register(L.room, z) then
        log("build: room registration failed")
        return false
    end
    placeSwitch(L, z)
    aparosa_BD_Rooms.remember(L, z, variant)
    log(string.format("build done ax=%d ay=%d z=%d orient=%d variant=%s", L.ax, L.ay, z, L.orient, variant))
    return true
end
