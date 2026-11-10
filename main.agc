// ============================================================================
//  SYVYYSPOMMIT  -  AppGameKit (Tier 1 BASIC)
//
//  Ei tarvitse yhtaan kuvatiedostoa: kaikki grafiikka on piirretty AGK:n omilla
//  piirtokomennoilla (DrawBox / DrawEllipse / DrawLine) seka varillisilla
//  "tyhjilla" sprite-laatoilla taustana.
//
//  Ohjaus:  Nuolet (tai A/D) = ohjaa havittajaa
//           SPACE            = heita syvyyspommi perasta
//           Z                = rajayta VANHIN laukaistu pommi (jarjestyksessa)
//           ENTER            = uusi peli (kun peli on ohi)
//
//  Pisteet: sukellusvene +100, sinivalas -300, kalmari -25, pikkukala 0
//  Sukellusveneet nousevat hitaasti pintaan. Kun yksi paasee pintaan,
//  se laukaisee mannerten valisen ydinohjuksen ja peli on havitty.
// ============================================================================

#constant SCRW      1024
#constant SCRH      768
#constant WATERY    230
#constant SEABED    724
#constant EXPLR     125
#constant MAXBOMBS  12

#constant T_SCORE   1
#constant T_HELP    2
#constant T_BOMBS   3
#constant T_THREAT  4
#constant T_OVER1   5
#constant T_OVER2   6
#constant T_OVER3   7
#constant T_POP     30

#constant SNDRATE   16000
#constant S_THROW   1
#constant S_SPLASH  2
#constant S_THUD    3
#constant S_BOOM    4
#constant S_KILL    5
#constant S_WHALE   6
#constant S_SQUID   7
#constant S_ALARM   8
#constant S_LAUNCH  9
#constant S_CLICK   10
#constant S_PING    11

type tCr
    alive as integer
    kind as integer
    x as float
    y as float
    by as float
    vx as float
    vy as float
    f as integer
    t as float
    ent as integer
    v as integer
endtype

type tBomb
    alive as integer
    state as integer
    serial as integer
    x as float
    y as float
    vx as float
    vy as float
endtype

type tExp
    alive as integer
    kind as integer
    x as float
    y as float
    t as float
    maxr as float
endtype

type tPart
    alive as integer
    kind as integer
    x as float
    y as float
    vx as float
    vy as float
    life as float
    maxlife as float
    size as float
endtype

type tPop
    alive as integer
    x as float
    y as float
    t as float
    r as integer
    g as integer
    b as integer
endtype

global cr as tCr[60]
global bm as tBomb[40]
global xp as tExp[24]
global pp as tPart[300]
global po as tPop[11]

global shipX as float
global shipV as float
global shipF as integer
global shk as float

global score as integer
global state as integer
global gameT as float
global animT as float
global nextSerial as integer
global bombCd as float

global spawnSub as float
global spawnWhale as float
global spawnSquid as float
global spawnFish as float

global msOn as integer
global msX as float
global msY as float
global msV as float
global msFlash as integer
global flashA as float
global showEnd as integer
global alarmCd as float
global pingCd as float

// ----------------------------------------------------------------------------
//  Alustus
// ----------------------------------------------------------------------------
SetWindowTitle("Syvyyspommit")
SetWindowSize(SCRW, SCRH, 0)
SetVirtualResolution(SCRW, SCRH)
SetSyncRate(60, 0)
SetClearColor(0, 0, 0)
SetRandomSeed(GetSeconds())

Print("Luodaan aanet...")
Sync()
MakeSounds()

SetupScene()
NewGame()

dtm as float

do
    dtm = GetFrameTime()
    if dtm > 0.05
        dtm = 0.05
    endif

    UpdateGame(dtm)
    DrawGame()
    UpdateHud()
    Sync()
loop

// ----------------------------------------------------------------------------
//  Apufunktiot
// ----------------------------------------------------------------------------

// ABGR-vari alfakanavalla (toimii kaikissa AGK2-versioissa)
function Col(r as integer, g as integer, b as integer, a as integer)
    c as integer
    if a < 0
        a = 0
    endif
    if a > 255
        a = 255
    endif
    c = (a << 24) || (b << 16) || (g << 8) || r
endfunction c

function FMin(a as float, b as float)
    r as float
    r = a
    if b < a
        r = b
    endif
endfunction r

function FMax(a as float, b as float)
    r as float
    r = a
    if b > a
        r = b
    endif
endfunction r

function RF(lo as float, hi as float)
    v as float
    v = lo + (hi - lo) * Random(0, 10000) / 10000.0
endfunction v

// taytetty kolmio viuhkana viivoja
function FillTri(x1 as float, y1 as float, x2 as float, y2 as float, x3 as float, y3 as float, c as integer)
    dx as float
    dy as float
    n as integer
    i as integer
    dx = x3 - x2
    dy = y3 - y2
    n = Trunc(Sqrt(dx * dx + dy * dy)) + 2
    for i = 0 to n
        DrawLine(x1, y1, x2 + dx * i / n, y2 + dy * i / n, c, c)
    next i
endfunction

// ----------------------------------------------------------------------------
//  Aanet: syntetisoidaan muistilohkoon (sama tekniikka kuin yhteison createsound)
//  f0/f1 = alku- ja lopputaajuus Hz, dur = kesto s, vol = 0..1, att = nousuaika s
//  dp = vaimenemisen jyrkkyys (0 = tasainen, 1..3 = yha jyrkempi)
//  nmix = kohinan osuus 0..1, nk = kohinan kirkkaus (pieni = muriseva)
//  vspd/vdep = vibraton nopeus Hz ja syvyys
// ----------------------------------------------------------------------------
function MakeSnd(id as integer, f0 as float, f1 as float, dur as float, vol as float, att as float, dp as integer, nmix as float, nk as float, vspd as float, vdep as float)
    n as integer
    i as integer
    mem as integer
    v as integer
    p as float
    e as float
    f as float
    ph as float
    vph as float
    tone as float
    ns as float
    wn as float
    k as float
    nz as float
    smp as float
    env as float
    rel as float
    attN as float

    n = Trunc(dur * SNDRATE)
    mem = CreateMemblock(12 + n * 2)
    SetMemblockShort(mem, 0, 1)
    SetMemblockShort(mem, 2, 16)
    SetMemblockInt(mem, 4, SNDRATE)
    SetMemblockInt(mem, 8, n)

    ph = 0
    vph = 0
    ns = 0
    attN = att * SNDRATE + 1

    for i = 0 to n - 1
        p = i / (n * 1.0)
        e = 1 - p

        f = f0 + (f1 - f0) * (1 - e * e)
        vph = vph + 360.0 * vspd / SNDRATE
        ph = ph + 360.0 * f * (1 + vdep * Sin(vph)) / SNDRATE
        tone = 0.75 * Sin(ph) + 0.25 * Sin(ph * 2)

        nz = 0
        if nmix > 0
            k = nk * (1 - 0.75 * p) + 0.01
            if k > 1
                k = 1
            endif
            wn = Random(-1000, 1000) / 1000.0
            ns = ns + (wn - ns) * k
            nz = ns * Sqrt((2 - k) / k) * 0.7
            if nz > 1
                nz = 1
            endif
            if nz < -1
                nz = -1
            endif
        endif
        smp = (1 - nmix) * tone + nmix * nz

        env = 1
        if dp >= 1
            env = e
        endif
        if dp >= 2
            env = env * e
        endif
        if dp >= 3
            env = env * e
        endif
        if i < attN
            env = env * i / attN
        endif
        rel = e * 12.5
        if rel < 1
            env = env * rel
        endif

        v = Trunc(smp * env * vol * 30000)
        if v > 32000
            v = 32000
        endif
        if v < -32000
            v = -32000
        endif
        SetMemblockShort(mem, 12 + i * 2, v)
    next i

    if GetSoundExists(id) = 1
        DeleteSound(id)
    endif
    CreateSoundFromMemblock(id, mem)
    DeleteMemblock(mem)
endfunction

function MakeSounds()
    //         id        f0    f1    dur   vol   att    dp nmix  nk    vspd vdep
    MakeSnd(S_THROW,    220,   90, 0.09, 0.50, 0.003, 2, 0.35, 0.30,   0, 0.00)   // pommi irtoaa telineesta
    MakeSnd(S_SPLASH,     0,    0, 0.35, 0.60, 0.010, 2, 1.00, 0.35,   0, 0.00)   // roiske
    MakeSnd(S_THUD,      90,   28, 0.55, 0.95, 0.002, 2, 0.25, 0.08,   0, 0.00)   // jysahdys pohjaan
    MakeSnd(S_BOOM,     110,   22, 1.50, 1.00, 0.004, 2, 0.70, 0.12,   0, 0.00)   // syvyyspommin rajahdys
    MakeSnd(S_KILL,     520,   70, 0.55, 0.60, 0.003, 2, 0.50, 0.50,  38, 0.35)   // sukellusveneen runko murtuu
    MakeSnd(S_WHALE,    260,  110, 1.70, 0.60, 0.150, 1, 0.00, 1.00,   5, 0.06)   // sinivalaan valitus
    MakeSnd(S_SQUID,    700,  180, 0.22, 0.55, 0.004, 2, 0.10, 0.80,  30, 0.15)   // kalmarin blup
    MakeSnd(S_ALARM,    880,  880, 0.16, 0.45, 0.005, 0, 0.00, 1.00,   0, 0.00)   // halytyspiippaus
    MakeSnd(S_LAUNCH,    70,  500, 2.40, 0.90, 0.250, 1, 0.80, 0.25,   0, 0.00)   // ydinohjuksen laukaisu
    MakeSnd(S_CLICK,   1800,  900, 0.03, 0.30, 0.001, 2, 0.20, 0.70,   0, 0.00)   // ei pommeja: tyhja klik
    MakeSnd(S_PING,    1250, 1250, 1.30, 0.50, 0.004, 2, 0.00, 1.00,   0, 0.00)   // kaikuluotain
endfunction

function SetStrip(id as integer, y as float, h as float, r as float, g as float, b as float)
    CreateSprite(id, 0)
    SetSpriteSize(id, SCRW, h)
    SetSpritePosition(id, 0, y)
    SetSpriteColor(id, Trunc(r), Trunc(g), Trunc(b), 255)
    SetSpriteDepth(id, 1000)
endfunction

function MakeText(id as integer, s as string, size as float, x as float, y as float, align as integer)
    CreateText(id, s)
    SetTextSize(id, size)
    SetTextPosition(id, x, y)
    SetTextAlignment(id, align)
    SetTextColor(id, 255, 255, 255, 255)
    SetTextDepth(id, 5)
endfunction

function SetupScene()
    i as integer
    t as float
    for i = 0 to 10
        t = i / 10.0
        SetStrip(1 + i, i * WATERY / 11.0, WATERY / 11.0 + 2, 70 + 85 * t, 92 + 85 * t, 120 + 70 * t)
    next i
    for i = 0 to 23
        t = i / 23.0
        SetStrip(20 + i, WATERY + i * (SCRH - WATERY) / 24.0, (SCRH - WATERY) / 24.0 + 2, 38 - 35 * t, 118 - 98 * t, 150 - 108 * t)
    next i

    MakeText(T_SCORE, "", 30, 16, 8, 0)
    MakeText(T_HELP, "Nuolet = liiku   Space = pommi   Z = r" + Chr(228) + "j" + Chr(228) + "yt" + Chr(228) + " vanhin", 20, 16, 46, 0)
    MakeText(T_BOMBS, "", 20, 16, 70, 0)
    MakeText(T_THREAT, "SUKELLUSVENEIDEN UHKA", 18, 700, 8, 0)
    MakeText(T_OVER1, "YDINOHJUS LAUKAISTU!", 54, SCRW / 2, 40, 1)
    MakeText(T_OVER2, "", 30, SCRW / 2, 112, 1)
    MakeText(T_OVER3, "ENTER = uusi peli", 26, SCRW / 2, 154, 1)
    SetTextColor(T_OVER1, 255, 70, 50, 255)
    SetTextColor(T_THREAT, 255, 230, 200, 255)

    for i = 0 to 11
        MakeText(T_POP + i, "", 26, 0, 0, 1)
        SetTextVisible(T_POP + i, 0)
    next i
endfunction

function NewGame()
    i as integer
    for i = 0 to 60
        cr[i].alive = 0
    next i
    for i = 0 to 40
        bm[i].alive = 0
    next i
    for i = 0 to 24
        xp[i].alive = 0
    next i
    for i = 0 to 300
        pp[i].alive = 0
    next i
    for i = 0 to 11
        po[i].alive = 0
        SetTextVisible(T_POP + i, 0)
    next i

    shipX = SCRW / 2
    shipV = 0
    shipF = 1
    shk = 0
    score = 0
    state = 1
    gameT = 0
    nextSerial = 1
    bombCd = 0
    spawnSub = 3
    spawnWhale = 9
    spawnSquid = 2
    spawnFish = 1
    msOn = 0
    msFlash = 0
    flashA = 0
    showEnd = 0
    alarmCd = 0
    pingCd = 4

    SetTextVisible(T_OVER1, 0)
    SetTextVisible(T_OVER2, 0)
    SetTextVisible(T_OVER3, 0)

    i = FreeCr()
    InitCr(i, 2, 260, 470, -32, 0)
    SpawnFish()
endfunction

// ----------------------------------------------------------------------------
//  Laskurit ja varausfunktiot
// ----------------------------------------------------------------------------
function FreeCr()
    i as integer
    r as integer
    r = -1
    for i = 0 to 60
        if cr[i].alive = 0
            r = i
            exit
        endif
    next i
endfunction r

function CountKind(k as integer)
    i as integer
    n as integer
    n = 0
    for i = 0 to 60
        if cr[i].alive = 1 and cr[i].kind = k
            n = n + 1
        endif
    next i
endfunction n

function CountBombs()
    i as integer
    n as integer
    n = 0
    for i = 0 to 40
        if bm[i].alive = 1
            n = n + 1
        endif
    next i
endfunction n

function OldestSerial()
    i as integer
    s as integer
    s = 999999999
    for i = 0 to 40
        if bm[i].alive = 1 and bm[i].serial < s
            s = bm[i].serial
        endif
    next i
endfunction s

function InitCr(i as integer, kind as integer, x as float, y as float, vx as float, vy as float)
    cr[i].alive = 1
    cr[i].kind = kind
    cr[i].x = x
    cr[i].y = y
    cr[i].by = y
    cr[i].vx = vx
    cr[i].vy = vy
    cr[i].f = 1
    if vx < 0
        cr[i].f = -1
    endif
    cr[i].t = RF(0, 10)
    cr[i].ent = 0
    cr[i].v = Random(0, 2)
endfunction

function AddPart(kind as integer, x as float, y as float, vx as float, vy as float, life as float, size as float)
    i as integer
    for i = 0 to 300
        if pp[i].alive = 0
            pp[i].alive = 1
            pp[i].kind = kind
            pp[i].x = x
            pp[i].y = y
            pp[i].vx = vx
            pp[i].vy = vy
            pp[i].life = life
            pp[i].maxlife = life
            pp[i].size = size
            exit
        endif
    next i
endfunction

function Popup(x as float, y as float, s as string, r as integer, g as integer, b as integer)
    i as integer
    for i = 0 to 11
        if po[i].alive = 0
            po[i].alive = 1
            po[i].x = x
            po[i].y = y
            po[i].t = 0
            po[i].r = r
            po[i].g = g
            po[i].b = b
            SetTextString(T_POP + i, s)
            SetTextColor(T_POP + i, r, g, b, 255)
            SetTextPosition(T_POP + i, x, y)
            SetTextVisible(T_POP + i, 1)
            exit
        endif
    next i
endfunction

// ----------------------------------------------------------------------------
//  Spawnaus
// ----------------------------------------------------------------------------
function SpawnSub()
    i as integer
    sp as float
    i = FreeCr()
    if i >= 0
        sp = RF(24, 48)
        if Random(0, 1) = 0
            InitCr(i, 1, -130, RF(420, SEABED - 60), sp, 0)
        else
            InitCr(i, 1, SCRW + 130, RF(420, SEABED - 60), -sp, 0)
        endif
        // nousunopeus kasvaa pelin edetessa
        cr[i].vy = -(RF(8, 12) + FMin(gameT * 0.04, 10.0))
    endif
endfunction

function SpawnWhale()
    i as integer
    sp as float
    yy as float
    i = FreeCr()
    if i >= 0
        sp = RF(28, 46)
        yy = RF(330, 620)
        if Random(0, 1) = 0
            InitCr(i, 2, -300, yy, sp, 0)
        else
            InitCr(i, 2, SCRW + 300, yy, -sp, 0)
        endif
    endif
endfunction

function SpawnSquid()
    i as integer
    sp as float
    yy as float
    i = FreeCr()
    if i >= 0
        sp = RF(70, 110)
        yy = RF(300, 640)
        if Random(0, 1) = 0
            InitCr(i, 3, -110, yy, sp, RF(-10, 10))
        else
            InitCr(i, 3, SCRW + 110, yy, -sp, RF(-10, 10))
        endif
    endif
endfunction

function SpawnFish()
    n as integer
    i as integer
    j as integer
    dr as integer
    vv as integer
    yy as float
    sp as float
    n = Random(3, 6)
    yy = RF(300, SEABED - 70)
    sp = RF(45, 80)
    vv = Random(0, 2)
    dr = 1
    if Random(0, 1) = 0
        dr = -1
    endif
    for j = 1 to n
        i = FreeCr()
        if i >= 0
            if dr = 1
                InitCr(i, 4, -30 - j * RF(14, 30), yy + RF(-30, 30), sp * RF(0.9, 1.1), 0)
            else
                InitCr(i, 4, SCRW + 30 + j * RF(14, 30), yy + RF(-30, 30), -sp * RF(0.9, 1.1), 0)
            endif
            cr[i].v = vv
        endif
    next j
endfunction

function Spawns(dt as float)
    spawnSub = spawnSub - dt
    if spawnSub <= 0
        if CountKind(1) < 4 + Trunc(gameT / 60.0)
            SpawnSub()
        endif
        spawnSub = FMax(2.4, 7.0 - gameT * 0.03) * RF(0.8, 1.2)
    endif

    spawnWhale = spawnWhale - dt
    if spawnWhale <= 0
        if CountKind(2) < 2
            SpawnWhale()
        endif
        spawnWhale = RF(14, 24)
    endif

    spawnSquid = spawnSquid - dt
    if spawnSquid <= 0
        if CountKind(3) < 4
            SpawnSquid()
        endif
        spawnSquid = RF(4, 8)
    endif

    spawnFish = spawnFish - dt
    if spawnFish <= 0
        if CountKind(4) < 16
            SpawnFish()
        endif
        spawnFish = RF(5, 9)
    endif
endfunction

// ----------------------------------------------------------------------------
//  Paivitys
// ----------------------------------------------------------------------------
function UpdateGame(dt as float)
    th as float
    animT = animT + dt
    shk = shk * (1 - 6 * dt)

    if state = 1
        gameT = gameT + dt
        Spawns(dt)
        bombCd = bombCd - dt

        // halytys kiihtyy, kun sukellusvene lahestyy pintaa
        th = ThreatLevel()
        alarmCd = alarmCd - dt
        if th > 0.7 and alarmCd <= 0
            PlaySound(S_ALARM, 55, 0)
            alarmCd = 0.9 - (th - 0.7) * 2.2
        endif

        // taustalla kaikuluotain
        pingCd = pingCd - dt
        if pingCd <= 0
            PlaySound(S_PING, 28, 0)
            pingCd = RF(5, 9)
        endif

        if GetRawKeyPressed(32) = 1 and bombCd <= 0
            DropBomb()
        endif
        if GetRawKeyPressed(90) = 1
            DetonateOldest()
        endif
    else
        UpdateMissile(dt)
        if GetRawKeyPressed(13) = 1
            NewGame()
        endif
    endif

    UpdateShip(dt)
    UpdateBombs(dt)
    UpdateCreatures(dt)
    UpdateExp(dt)
    UpdateParts(dt)
    UpdatePops(dt)
endfunction

function UpdateShip(dt as float)
    ax as integer
    ax = 0
    if state = 1
        if GetRawKeyState(37) = 1 or GetRawKeyState(65) = 1
            ax = ax - 1
        endif
        if GetRawKeyState(39) = 1 or GetRawKeyState(68) = 1
            ax = ax + 1
        endif
    endif

    if ax <> 0
        shipV = shipV + ax * 320 * dt
        shipF = ax
    else
        shipV = shipV * (1 - 1.3 * dt)
    endif
    if shipV > 170
        shipV = 170
    endif
    if shipV < -170
        shipV = -170
    endif

    shipX = shipX + shipV * dt
    if shipX < 120
        shipX = 120
        shipV = 0
    endif
    if shipX > SCRW - 120
        shipX = SCRW - 120
        shipV = 0
    endif

    // keulan vaahto
    if Abs(shipV) > 25 and Random(0, 100) < 45
        AddPart(0, shipX + shipF * 92, WATERY + RF(0, 8), RF(-10, 10), RF(-8, -2), RF(0.6, 1.2), RF(2, 4))
        AddPart(0, shipX - shipF * 92, WATERY + RF(0, 10), RF(-20, 20), RF(-12, -2), RF(0.8, 1.6), RF(2, 5))
    endif
endfunction

function DropBomb()
    i as integer
    j as integer
    j = -1
    if CountBombs() < MAXBOMBS
        for i = 0 to 40
            if bm[i].alive = 0
                j = i
                exit
            endif
        next i
    endif
    if j >= 0
        bm[j].alive = 1
        bm[j].state = 0
        bm[j].serial = nextSerial
        nextSerial = nextSerial + 1
        bm[j].x = shipX - shipF * 88
        bm[j].y = WATERY - 36
        bm[j].vx = -shipF * 70 + shipV * 0.6
        bm[j].vy = -170
        bombCd = 0.22
        PlaySound(S_THROW, 60, 0)
    endif
endfunction

function DetonateOldest()
    i as integer
    best as integer
    s as integer
    best = -1
    s = 999999999
    for i = 0 to 40
        if bm[i].alive = 1 and bm[i].serial < s
            s = bm[i].serial
            best = i
        endif
    next i
    if best >= 0
        bm[best].alive = 0
        Explode(bm[best].x, bm[best].y)
    else
        PlaySound(S_CLICK, 50, 0)
    endif
endfunction

function UpdateBombs(dt as float)
    i as integer
    for i = 0 to 40
        if bm[i].alive = 1
            if bm[i].state = 0
                bm[i].vy = bm[i].vy + 620 * dt
                bm[i].x = bm[i].x + bm[i].vx * dt
                bm[i].y = bm[i].y + bm[i].vy * dt
                if bm[i].y >= WATERY
                    bm[i].state = 1
                    bm[i].vy = 90
                    bm[i].vx = bm[i].vx * 0.3
                    Splash(bm[i].x, 8)
                    PlaySound(S_SPLASH, 55, 0)
                endif
            elseif bm[i].state = 1
                bm[i].vy = bm[i].vy + 260 * dt
                if bm[i].vy > 175
                    bm[i].vy = 175
                endif
                bm[i].vx = bm[i].vx * (1 - 2.2 * dt)
                bm[i].x = bm[i].x + bm[i].vx * dt
                bm[i].y = bm[i].y + bm[i].vy * dt
                if Random(0, 100) < 12
                    AddPart(0, bm[i].x, bm[i].y - 8, RF(-8, 8), RF(-40, -15), RF(0.6, 1.2), RF(1.5, 3))
                endif
                if bm[i].y >= SEABED - 10
                    bm[i].y = SEABED - 10
                    bm[i].state = 2
                    bm[i].vx = 0
                    bm[i].vy = 0
                    Thud(bm[i].x, bm[i].y)
                endif
            endif
        endif
    next i
endfunction

// pommi osuu pohjaan: jysahdys
function Thud(x as float, y as float)
    i as integer
    shk = shk + 5
    PlaySound(S_THUD, 90, 0)
    for i = 0 to 24
        if xp[i].alive = 0
            xp[i].alive = 1
            xp[i].kind = 1
            xp[i].x = x
            xp[i].y = y + 8
            xp[i].t = 0
            xp[i].maxr = 60
            exit
        endif
    next i
    for i = 1 to 14
        AddPart(1, x + RF(-10, 10), y + 8, RF(-110, 110), RF(-70, -10), RF(0.6, 1.3), RF(2, 5))
    next i
endfunction

function Splash(x as float, n as integer)
    i as integer
    for i = 1 to n
        AddPart(2, x + RF(-6, 6), WATERY, RF(-60, 60), -RF(120, 260), RF(0.6, 1.0), RF(1.5, 3))
    next i
endfunction

function CrRadius(k as integer)
    r as float
    r = 12
    if k = 1
        r = 70
    endif
    if k = 2
        r = 110
    endif
    if k = 3
        r = 28
    endif
endfunction r

function Explode(x as float, y as float)
    i as integer
    dx as float
    dy as float
    d as float
    ang as float
    sp as float

    shk = shk + 12
    PlaySound(S_BOOM, 100, 0)
    for i = 0 to 24
        if xp[i].alive = 0
            xp[i].alive = 1
            xp[i].kind = 0
            xp[i].x = x
            xp[i].y = y
            xp[i].t = 0
            xp[i].maxr = EXPLR
            exit
        endif
    next i

    for i = 0 to 60
        if cr[i].alive = 1
            dx = cr[i].x - x
            dy = cr[i].y - y
            d = Sqrt(dx * dx + dy * dy)
            if d < EXPLR + CrRadius(cr[i].kind)
                KillCr(i)
            endif
        endif
    next i

    for i = 1 to 26
        AddPart(0, x + RF(-40, 40), y + RF(-30, 30), RF(-30, 30), -RF(30, 90), RF(1.5, 3.0), RF(2, 6))
    next i
    for i = 1 to 22
        ang = RF(0, 360)
        sp = RF(80, 320)
        AddPart(4, x, y, Cos(ang) * sp, Sin(ang) * sp, RF(0.3, 0.7), RF(2, 4))
    next i
    if y < WATERY + 170
        Splash(x, 22)
    endif
    if y > SEABED - 70
        for i = 1 to 12
            AddPart(1, x + RF(-40, 40), SEABED, RF(-120, 120), -RF(20, 120), RF(0.8, 1.6), RF(2, 5))
        next i
    endif
endfunction

function KillCr(i as integer)
    k as integer
    j as integer
    x as float
    y as float
    k = cr[i].kind
    x = cr[i].x
    y = cr[i].y
    if k = 1
        score = score + 100
        PlaySound(S_KILL, 85, 0)
        Popup(x - 25, y - 60, "+100", 255, 235, 90)
        for j = 1 to 16
            AddPart(3, x + RF(-70, 70), y + RF(-12, 12), RF(-120, 120), RF(-100, 40), RF(1, 2.2), RF(2, 5))
        next j
    elseif k = 2
        score = score - 300
        PlaySound(S_WHALE, 80, 0)
        Popup(x - 80, y - 70, "-300 Sinivalas!", 255, 90, 90)
    elseif k = 3
        score = score - 25
        PlaySound(S_SQUID, 70, 0)
        Popup(x - 45, y - 40, "-25 Kalmari", 255, 160, 140)
    endif
    for j = 1 to 10
        AddPart(0, x + RF(-20, 20), y + RF(-15, 15), RF(-30, 30), -RF(20, 70), RF(1, 2.2), RF(2, 5))
    next j
    cr[i].alive = 0
endfunction

function LaunchMissile(i as integer)
    state = 2
    msOn = 1
    msX = cr[i].x
    msY = cr[i].y - 50
    msV = -40
    msFlash = 0
    flashA = 0
    showEnd = 0
    cr[i].vx = 0
    cr[i].vy = 0
    PlaySound(S_LAUNCH, 100, 0)
    Popup(cr[i].x - 60, WATERY + 30, "LAUKAISU!", 255, 60, 40)
endfunction

function UpdateMissile(dt as float)
    if msOn = 1
        msV = msV - 420 * dt
        msY = msY + msV * dt
        AddPart(5, msX + RF(-3, 3), msY + 40, RF(-12, 12), RF(20, 60), RF(0.8, 1.6), RF(4, 9))
        AddPart(4, msX + RF(-3, 3), msY + 38, RF(-30, 30), RF(60, 160), RF(0.2, 0.4), RF(2, 4))
        if msY < -90 and msFlash = 0
            msFlash = 1
            flashA = 255
            PlaySound(S_BOOM, 100, 0)
        endif
        if msFlash = 1
            flashA = flashA - 170 * dt
            if flashA <= 0
                flashA = 0
                showEnd = 1
            endif
        endif
    endif
endfunction

function UpdateCreatures(dt as float)
    i as integer
    k as integer
    pulse as float
    mg as float
    for i = 0 to 60
        if cr[i].alive = 1
            k = cr[i].kind
            cr[i].t = cr[i].t + dt

            if k = 1
                cr[i].x = cr[i].x + cr[i].vx * dt
                cr[i].y = cr[i].y + cr[i].vy * dt + Sin(cr[i].t * 70) * 5 * dt
                if cr[i].y < WATERY + 14
                    cr[i].y = WATERY + 14
                endif
                if cr[i].ent = 0
                    if cr[i].x > 110 and cr[i].x < SCRW - 110
                        cr[i].ent = 1
                    endif
                else
                    if cr[i].x < 110 and cr[i].vx < 0
                        cr[i].vx = -cr[i].vx
                        cr[i].f = 1
                    endif
                    if cr[i].x > SCRW - 110 and cr[i].vx > 0
                        cr[i].vx = -cr[i].vx
                        cr[i].f = -1
                    endif
                endif
                if Random(0, 100) < 6
                    AddPart(0, cr[i].x - cr[i].f * 105, cr[i].y, RF(-5, 5), RF(-30, -10), RF(0.8, 1.6), RF(1.5, 3))
                endif
                // pinnalla: ydinohjus laukaistaan
                if state = 1 and cr[i].y <= WATERY + 16
                    LaunchMissile(i)
                endif

            elseif k = 2
                cr[i].x = cr[i].x + cr[i].vx * dt
                cr[i].y = cr[i].by + Sin(cr[i].t * 40) * 14
                mg = 300

            elseif k = 3
                pulse = 0.25 + 1.5 * FMax(0.0, Sin(cr[i].t * 170))
                cr[i].x = cr[i].x + cr[i].vx * pulse * dt
                cr[i].y = cr[i].y + cr[i].vy * dt
                if cr[i].y < 300 and cr[i].vy < 0
                    cr[i].vy = -cr[i].vy
                endif
                if cr[i].y > SEABED - 80 and cr[i].vy > 0
                    cr[i].vy = -cr[i].vy
                endif
                mg = 140

            elseif k = 4
                cr[i].x = cr[i].x + cr[i].vx * dt
                cr[i].y = cr[i].by + Sin(cr[i].t * 120) * 5
                mg = 70
            endif

            if k > 1
                if cr[i].ent = 0
                    if cr[i].x > 0 and cr[i].x < SCRW
                        cr[i].ent = 1
                    endif
                else
                    if cr[i].x < -mg or cr[i].x > SCRW + mg
                        cr[i].alive = 0
                    endif
                endif
            endif
        endif
    next i
endfunction

function UpdateExp(dt as float)
    i as integer
    for i = 0 to 24
        if xp[i].alive = 1
            xp[i].t = xp[i].t + dt
            if xp[i].t > 0.9
                xp[i].alive = 0
            endif
        endif
    next i
endfunction

function UpdateParts(dt as float)
    i as integer
    k as integer
    for i = 0 to 300
        if pp[i].alive = 1
            k = pp[i].kind
            pp[i].life = pp[i].life - dt
            pp[i].x = pp[i].x + pp[i].vx * dt
            pp[i].y = pp[i].y + pp[i].vy * dt

            if k = 0
                pp[i].vx = pp[i].vx + RF(-60, 60) * dt
                if pp[i].y < WATERY
                    pp[i].alive = 0
                endif
            elseif k = 1
                pp[i].vy = pp[i].vy * (1 - 1.8 * dt)
                pp[i].vx = pp[i].vx * (1 - 1.8 * dt)
            elseif k = 2
                pp[i].vy = pp[i].vy + 700 * dt
                if pp[i].y > WATERY and pp[i].vy > 0
                    pp[i].alive = 0
                endif
            elseif k = 3
                pp[i].vy = pp[i].vy + 140 * dt
                pp[i].vx = pp[i].vx * (1 - 1.2 * dt)
                if pp[i].y > SEABED
                    pp[i].alive = 0
                endif
            elseif k = 4
                pp[i].vx = pp[i].vx * (1 - 3 * dt)
                pp[i].vy = pp[i].vy * (1 - 3 * dt)
            elseif k = 5
                pp[i].size = pp[i].size + 6 * dt
            endif

            if pp[i].life <= 0
                pp[i].alive = 0
            endif
        endif
    next i
endfunction

function UpdatePops(dt as float)
    i as integer
    a as integer
    for i = 0 to 11
        if po[i].alive = 1
            po[i].t = po[i].t + dt
            po[i].y = po[i].y - 40 * dt
            a = Trunc(255 * (1 - po[i].t / 1.8))
            if a < 0
                a = 0
            endif
            SetTextPosition(T_POP + i, po[i].x, po[i].y)
            SetTextColor(T_POP + i, po[i].r, po[i].g, po[i].b, a)
            if po[i].t > 1.8
                po[i].alive = 0
                SetTextVisible(T_POP + i, 0)
            endif
        endif
    next i
endfunction

function ThreatLevel()
    i as integer
    th as float
    f as float
    th = 0
    for i = 0 to 60
        if cr[i].alive = 1 and cr[i].kind = 1
            f = 1 - (cr[i].y - (WATERY + 16)) / (SEABED - (WATERY + 16))
            if f > th
                th = f
            endif
        endif
    next i
    if th < 0
        th = 0
    endif
    if th > 1
        th = 1
    endif
endfunction th

function UpdateHud()
    SetTextString(T_SCORE, "Pisteet: " + Str(score))
    if score < 0
        SetTextColor(T_SCORE, 255, 120, 110, 255)
    else
        SetTextColor(T_SCORE, 255, 255, 255, 255)
    endif
    SetTextString(T_BOMBS, "Pommit vedess" + Chr(228) + ": " + Str(CountBombs()) + " / " + Str(MAXBOMBS))

    if showEnd = 1
        SetTextString(T_OVER2, "Peli p" + Chr(228) + Chr(228) + "ttyi.   Pisteet: " + Str(score))
        SetTextVisible(T_OVER1, 1)
        SetTextVisible(T_OVER2, 1)
        SetTextVisible(T_OVER3, 1)
    endif
endfunction

// ----------------------------------------------------------------------------
//  Piirto
// ----------------------------------------------------------------------------
function DrawGame()
    i as integer
    k as integer
    oldest as integer
    nxt as integer

    // aurinko
    DrawEllipse(910, 118, 34, 34, Col(255, 248, 215, 210), Col(255, 228, 170, 210), 1)

    DrawSeabed()

    // elaimet taka-alalta eteen
    for k = 4 to 1 step -1
        for i = 0 to 60
            if cr[i].alive = 1 and cr[i].kind = k
                if k = 1
                    DrawSub(cr[i].x, cr[i].y, cr[i].f, cr[i].t)
                elseif k = 2
                    DrawWhale(cr[i].x, cr[i].y, cr[i].f, cr[i].t)
                elseif k = 3
                    DrawSquid(cr[i].x, cr[i].y, cr[i].f, cr[i].t)
                else
                    DrawFish(cr[i].x, cr[i].y, cr[i].f, cr[i].t, cr[i].v)
                endif
            endif
        next i
    next k

    // syvyyspommit
    oldest = OldestSerial()
    for i = 0 to 40
        if bm[i].alive = 1
            nxt = 0
            if bm[i].serial = oldest
                nxt = 1
            endif
            DrawBomb(bm[i].x, bm[i].y, bm[i].state, nxt)
        endif
    next i

    DrawShip()

    // puolilapinakyva meri paalle
    DrawBox(0, WATERY, SCRW, SCRH, Col(100, 180, 220, 70), Col(100, 180, 220, 70), Col(0, 30, 80, 125), Col(0, 30, 80, 125), 1)
    DrawSurface()

    // rajahdykset
    for i = 0 to 24
        if xp[i].alive = 1
            DrawExp(xp[i].kind, xp[i].x, xp[i].y, xp[i].t, xp[i].maxr)
        endif
    next i

    DrawParts()
    DrawMissile()
    DrawHudBar()

    if flashA > 0
        DrawBox(0, 0, SCRW, SCRH, Col(255, 255, 255, Trunc(flashA)), Col(255, 255, 255, Trunc(flashA)), Col(255, 255, 255, Trunc(flashA)), Col(255, 255, 255, Trunc(flashA)), 1)
    endif
endfunction

function DrawSurface()
    x as integer
    y1 as float
    y2 as float
    for x = 0 to SCRW step 8
        y1 = WATERY + Sin(x * 1.3 + animT * 140) * 1.8
        y2 = WATERY + Sin((x + 8) * 1.3 + animT * 140) * 1.8
        DrawLine(x, y1, x + 8, y2, Col(225, 247, 255, 210), Col(225, 247, 255, 210))
    next x
endfunction

function DrawSeabed()
    k as integer
    j as integer
    bx as float
    h as float
    px as float
    py as float
    xx as float
    yy as float
    DrawBox(0, SEABED - 4, SCRW, SCRH, Col(120, 108, 84, 255), Col(120, 108, 84, 255), Col(52, 46, 38, 255), Col(52, 46, 38, 255), 1)
    DrawEllipse(120, SEABED + 8, 190, 24, Col(125, 112, 88, 255), Col(70, 62, 50, 255), 1)
    DrawEllipse(560, SEABED + 14, 260, 24, Col(118, 106, 82, 255), Col(62, 55, 45, 255), 1)
    DrawEllipse(930, SEABED + 6, 170, 26, Col(125, 112, 88, 255), Col(70, 62, 50, 255), 1)
    DrawEllipse(330, SEABED - 2, 26, 12, Col(80, 84, 92, 255), Col(40, 42, 50, 255), 1)
    DrawEllipse(790, SEABED - 1, 34, 14, Col(80, 84, 92, 255), Col(40, 42, 50, 255), 1)

    for k = 0 to 13
        bx = 30 + k * 75 + Mod(k * 37, 23)
        h = 45 + Mod(k * 29, 40)
        px = bx
        py = SEABED
        for j = 1 to 4
            yy = SEABED - h * j / 4.0
            xx = bx + Sin(animT * 60 + k * 50 + j * 40) * j * 3.5
            DrawLine(px, py, xx, yy, Col(40, 120, 70, 255), Col(60, 150, 80, 255))
            DrawLine(px + 1, py, xx + 1, yy, Col(40, 120, 70, 255), Col(60, 150, 80, 255))
            DrawLine(px + 2, py, xx + 2, yy, Col(40, 120, 70, 255), Col(60, 150, 80, 255))
            px = xx
            py = yy
        next j
    next k
endfunction

// ---------------- havittaja ----------------
function FX(sx as float, f as integer, u as float)
    r as float
    r = sx + f * (u - 95)
endfunction r

function FBox(sx as float, oy as float, f as integer, u1 as float, v1 as float, u2 as float, v2 as float, c1 as integer, c2 as integer)
    xa as float
    xb as float
    tmp as float
    xa = FX(sx, f, u1)
    xb = FX(sx, f, u2)
    if xa > xb
        tmp = xa
        xa = xb
        xb = tmp
    endif
    DrawBox(xa, oy + v1, xb, oy + v2, c1, c1, c2, c2, 1)
endfunction

function FLine(sx as float, oy as float, f as integer, u1 as float, v1 as float, u2 as float, v2 as float, c as integer)
    DrawLine(FX(sx, f, u1), oy + v1, FX(sx, f, u2), oy + v2, c, c)
endfunction

function DrawShip()
    sx as float
    oy as float
    f as integer
    u as integer
    i as integer
    xx as float
    tp as float
    bt as float
    cH1 as integer
    cH2 as integer
    cS1 as integer
    cS2 as integer
    cDk as integer
    rw as float

    sx = shipX
    f = shipF
    oy = WATERY + Sin(animT * 100) * 1.6 + Sin(animT * 1700) * shk * 0.5

    cH1 = Col(150, 170, 192, 255)
    cH2 = Col(66, 82, 104, 255)
    cS1 = Col(168, 186, 204, 255)
    cS2 = Col(104, 122, 144, 255)
    cDk = Col(48, 58, 74, 255)

    // runko: pystyviivoja, keula nousee
    for u = 0 to 190
        xx = sx + f * (u - 95)
        tp = -30.0
        if u > 140
            tp = -30.0 - (u - 140) * 0.38
        endif
        bt = 14.0
        if u > 150
            bt = 14.0 - (u - 150) * 0.42
        endif
        if u < 10
            bt = 14.0 - (10 - u) * 0.6
        endif
        DrawLine(xx, oy + tp, xx, oy + bt, cH1, cH2)
    next u
    FBox(sx, oy, f, 8, 3, 148, 8, Col(120, 46, 46, 255), Col(120, 46, 46, 255))
    FBox(sx, oy, f, 0, -31, 142, -29, cDk, cDk)
    for i = 0 to 7
        rw = 20 + i * 15
        DrawEllipse(FX(sx, f, rw), oy - 16, 2, 2, cDk, cDk, 1)
    next i

    // peran syvyyspommiteline
    FBox(sx, oy, f, 2, -34, 34, -32, cDk, cDk)
    FBox(sx, oy, f, 6, -46, 17, -34, Col(96, 110, 98, 255), Col(50, 60, 52, 255))
    FBox(sx, oy, f, 21, -46, 32, -34, Col(96, 110, 98, 255), Col(50, 60, 52, 255))
    FBox(sx, oy, f, 6, -41, 17, -39, Col(180, 45, 40, 255), Col(180, 45, 40, 255))
    FBox(sx, oy, f, 21, -41, 32, -39, Col(180, 45, 40, 255), Col(180, 45, 40, 255))

    // kaiteet
    for i = 0 to 6
        FLine(sx, oy, f, 38 + i * 10, -30, 38 + i * 10, -38, cDk)
    next i
    FLine(sx, oy, f, 38, -38, 98, -38, cDk)

    // savupiippu
    FBox(sx, oy, f, 52, -68, 70, -30, cS1, cS2)
    FBox(sx, oy, f, 52, -68, 70, -62, cDk, cDk)

    // paallysrakenne ja silta
    FBox(sx, oy, f, 74, -58, 132, -30, cS1, cS2)
    FBox(sx, oy, f, 92, -80, 124, -58, cS1, cS2)
    FBox(sx, oy, f, 96, -72, 122, -67, Col(30, 44, 62, 255), Col(30, 44, 62, 255))
    FBox(sx, oy, f, 80, -50, 88, -46, Col(30, 44, 62, 255), Col(30, 44, 62, 255))
    FBox(sx, oy, f, 100, -50, 108, -46, Col(30, 44, 62, 255), Col(30, 44, 62, 255))

    // masto ja pyorivä tutka
    FLine(sx, oy, f, 108, -80, 108, -114, cDk)
    FLine(sx, oy, f, 99, -100, 117, -100, cDk)
    DrawEllipse(FX(sx, f, 108), oy - 118, 3 + 9 * Abs(Cos(animT * 260)), 2.5, Col(70, 80, 95, 255), Col(70, 80, 95, 255), 1)

    // keulatykki
    FBox(sx, oy, f, 150, -42, 168, -30, cS1, cS2)
    FLine(sx, oy, f, 168, -37, 190, -41, cDk)
    FLine(sx, oy, f, 168, -36, 190, -40, cDk)
endfunction

function DrawBomb(x as float, y as float, st as integer, isNext as integer)
    cL as integer
    cD as integer
    r as float
    cL = Col(120, 140, 124, 255)
    cD = Col(40, 52, 44, 255)
    DrawBox(x - 7, y - 10, x + 7, y + 10, cL, cD, cL, cD, 1)
    DrawEllipse(x, y - 10, 7, 3, cL, cL, 1)
    DrawEllipse(x, y + 10, 7, 3, cD, cD, 1)
    DrawBox(x - 7, y - 2, x + 7, y + 2, Col(200, 50, 40, 255), Col(200, 50, 40, 255), Col(200, 50, 40, 255), Col(200, 50, 40, 255), 1)
    if st = 2
        if Sin(animT * 700) > 0
            DrawEllipse(x, y - 12, 2.5, 2.5, Col(255, 60, 40, 255), Col(255, 60, 40, 255), 1)
        endif
    endif
    if isNext = 1
        r = 16 + Sin(animT * 500) * 2
        DrawEllipse(x, y, r, r, Col(255, 120, 60, 220), Col(255, 120, 60, 220), 0)
    endif
endfunction

// ---------------- sukellusvene ----------------
function DrawSub(x as float, y as float, f as integer, t as float)
    cHi as integer
    cLo as integer
    cTw as integer
    cDk as integer
    cLt as integer
    tx as float
    py as float
    i as integer
    cHi = Col(98, 106, 114, 255)
    cLo = Col(22, 24, 28, 255)
    cTw = Col(68, 74, 82, 255)
    cDk = Col(14, 15, 18, 255)
    cLt = Col(255, 220, 120, 210)

    FillTri(x - f * 70, y - 6, x - f * 106, y - 36, x - f * 98, y - 4, cDk)
    FillTri(x - f * 70, y + 6, x - f * 106, y + 30, x - f * 98, y + 4, cDk)

    DrawEllipse(x, y, 98, 19, cHi, cLo, 1)
    DrawLine(x - 62, y - 12, x + 62, y - 12, Col(150, 160, 170, 120), Col(150, 160, 170, 120))

    tx = x + f * 16
    DrawBox(tx - 22, y - 38, tx + 22, y - 12, cTw, cTw, cLo, cLo, 1)
    DrawEllipse(tx, y - 38, 22, 4, cTw, cTw, 1)
    DrawLine(tx + f * 6, y - 42, tx + f * 6, y - 62, cTw, cTw)
    DrawLine(tx + f * 6, y - 62, tx + f * 15, y - 62, cTw, cTw)
    DrawLine(tx - f * 8, y - 42, tx - f * 8, y - 54, cTw, cTw)
    for i = 0 to 2
        DrawEllipse(tx - 12 + i * 12, y - 27, 2.5, 2.5, cLt, cLt, 1)
    next i

    py = Sin(t * 900) * 15
    DrawLine(x - f * 103, y - py, x - f * 107, y + py, Col(75, 82, 90, 255), Col(75, 82, 90, 255))
endfunction

// ---------------- sinivalas ----------------
function DrawWhale(x as float, y as float, f as integer, t as float)
    cB as integer
    cL as integer
    cD as integer
    i as integer
    cx as float
    cy as float
    ry as float
    tipx as float
    tipy as float
    cB = Col(46, 86, 134, 255)
    cL = Col(150, 182, 208, 255)
    cD = Col(34, 64, 104, 255)

    for i = 8 to 0 step -1
        cx = x - f * (95 + i * 12)
        cy = y + Sin(t * 180 - i * 30) * (i * 1.7)
        ry = 30 - i * 3.2
        DrawEllipse(cx, cy, 24, ry, cB, cL, 1)
    next i

    tipx = x - f * (95 + 8 * 12 + 12)
    tipy = y + Sin(t * 180 - 240) * 13.6
    FillTri(tipx + f * 12, tipy, tipx - f * 16, tipy - 36, tipx - f * 4, tipy - 2, cD)
    FillTri(tipx + f * 12, tipy, tipx - f * 16, tipy + 36, tipx - f * 4, tipy + 2, cD)

    DrawEllipse(x, y, 118, 34, cB, cL, 1)
    DrawEllipse(x + f * 38, y, 88, 34, cB, cL, 1)

    for i = 0 to 5
        DrawEllipse(x - f * 60 + f * i * 28, y - 12 + Mod(i * 7, 5) * 3, 6, 2.5, Col(120, 160, 200, 90), Col(120, 160, 200, 90), 1)
    next i
    for i = 0 to 4
        DrawLine(x + f * 70, y + 14 + i * 3.5, x - f * 40, y + 16 + i * 3.5, Col(215, 230, 242, 110), Col(215, 230, 242, 110))
    next i

    FillTri(x - f * 40, y - 33, x - f * 72, y - 33, x - f * 68, y - 46, cD)
    FillTri(x + f * 58, y + 22, x + f * 18, y + 58 + Sin(t * 120) * 6, x + f * 32, y + 20, cD)

    DrawEllipse(x + f * 108, y + 6, 3.5, 3.5, Col(10, 10, 16, 255), Col(10, 10, 16, 255), 1)
    DrawLine(x + f * 124, y + 8, x + f * 66, y + 17, Col(25, 45, 75, 255), Col(25, 45, 75, 255))
endfunction

// ---------------- kalmari ----------------
function DrawSquid(x as float, y as float, f as integer, t as float)
    cA as integer
    cB as integer
    i as integer
    k as integer
    yo as float
    ln as float
    xs as float
    ys as float
    nx as float
    ny as float
    sq as float
    cA = Col(222, 100, 112, 255)
    cB = Col(150, 46, 72, 255)
    sq = Sin(t * 170) * 2

    FillTri(x - f * 22, y - 10, x - f * 52, y, x - f * 22, y + 10, cB)
    DrawEllipse(x - f * 14, y, 34, 11 + sq, cA, cB, 1)
    DrawEllipse(x + f * 20, y, 13, 10, cA, cB, 1)
    DrawEllipse(x + f * 23, y - 3, 4.5, 4.5, Col(250, 250, 240, 255), Col(250, 250, 240, 255), 1)
    DrawEllipse(x + f * 24, y - 3, 2, 2, Col(10, 10, 14, 255), Col(10, 10, 14, 255), 1)

    for i = 0 to 7
        yo = -7 + i * 2
        ln = 30 + Mod(i, 2) * 18
        xs = x + f * 30
        ys = y + yo
        for k = 1 to 4
            nx = xs + f * ln / 4.0
            ny = y + yo + Sin(t * 300 + i * 40 + k * 70) * k * 2.5
            DrawLine(xs, ys, nx, ny, cA, cB)
            xs = nx
            ys = ny
        next k
    next i
endfunction

// ---------------- kala ----------------
function DrawFish(x as float, y as float, f as integer, t as float, v as integer)
    c1 as integer
    c2 as integer
    wag as float
    if v = 0
        c1 = Col(190, 208, 216, 255)
        c2 = Col(90, 110, 122, 255)
    elseif v = 1
        c1 = Col(240, 212, 80, 255)
        c2 = Col(180, 120, 40, 255)
    else
        c1 = Col(236, 120, 76, 255)
        c2 = Col(150, 52, 42, 255)
    endif
    wag = Sin(t * 600) * 3
    FillTri(x - f * 8, y, x - f * 18, y - 6 + wag, x - f * 18, y + 6 + wag, c2)
    DrawEllipse(x, y, 11, 5.5, c1, c2, 1)
    DrawEllipse(x + f * 6, y - 1, 1.5, 1.5, Col(10, 10, 14, 255), Col(10, 10, 14, 255), 1)
endfunction

// ---------------- rajahdys, hiukkaset, ohjus ----------------
function DrawExp(kind as integer, x as float, y as float, t as float, maxr as float)
    p as float
    r as float
    a as integer
    if kind = 0
        p = t / 0.9
        r = maxr * (1 - (1 - p) * (1 - p))
        a = Trunc(210 * (1 - p))
        DrawEllipse(x, y, r, r * 0.92, Col(255, 150, 40, a), Col(255, 210, 120, a), 1)
        DrawEllipse(x, y, r * 0.55, r * 0.5, Col(255, 255, 235, a), Col(255, 255, 235, a), 1)
        DrawEllipse(x, y, r * 1.12, r * 1.04, Col(210, 240, 255, a), Col(210, 240, 255, a), 0)
        DrawEllipse(x, y, r * 1.2, r * 1.12, Col(210, 240, 255, Trunc(a * 0.5)), Col(210, 240, 255, Trunc(a * 0.5)), 0)
    else
        p = t / 0.9
        r = maxr * p
        a = Trunc(200 * (1 - p))
        DrawEllipse(x, y, r, r * 0.3, Col(220, 200, 150, a), Col(220, 200, 150, a), 0)
        DrawEllipse(x, y, r * 0.7, r * 0.2, Col(220, 200, 150, Trunc(a * 0.6)), Col(220, 200, 150, Trunc(a * 0.6)), 0)
    endif
endfunction

function DrawParts()
    i as integer
    k as integer
    a as integer
    s as float
    for i = 0 to 300
        if pp[i].alive = 1
            k = pp[i].kind
            s = pp[i].size
            a = Trunc(255 * pp[i].life / pp[i].maxlife)
            if k = 0
                DrawEllipse(pp[i].x, pp[i].y, s, s, Col(205, 238, 255, Trunc(a * 0.7)), Col(205, 238, 255, Trunc(a * 0.7)), 0)
            elseif k = 1
                DrawEllipse(pp[i].x, pp[i].y, s, s, Col(195, 175, 125, Trunc(a * 0.6)), Col(195, 175, 125, Trunc(a * 0.6)), 1)
            elseif k = 2
                DrawEllipse(pp[i].x, pp[i].y, s, s, Col(228, 246, 255, a), Col(228, 246, 255, a), 1)
            elseif k = 3
                DrawEllipse(pp[i].x, pp[i].y, s, s, Col(64, 64, 70, a), Col(64, 64, 70, a), 1)
            elseif k = 4
                DrawEllipse(pp[i].x, pp[i].y, s, s, Col(255, 205, 80, a), Col(255, 150, 40, a), 1)
            else
                DrawEllipse(pp[i].x, pp[i].y, s, s, Col(205, 205, 210, Trunc(a * 0.4)), Col(205, 205, 210, Trunc(a * 0.4)), 1)
            endif
        endif
    next i
endfunction

function DrawMissile()
    fl as float
    cL as integer
    cD as integer
    cR as integer
    if msOn = 1
        cL = Col(240, 240, 246, 255)
        cD = Col(140, 146, 160, 255)
        cR = Col(190, 40, 40, 255)
        fl = RF(14, 30)
        DrawEllipse(msX, msY + 32 + fl * 0.5, 8, fl, Col(255, 255, 210, 240), Col(255, 110, 20, 0), 1)
        FillTri(msX - 7, msY + 30, msX - 18, msY + 44, msX - 7, msY + 10, cR)
        FillTri(msX + 7, msY + 30, msX + 18, msY + 44, msX + 7, msY + 10, cR)
        DrawBox(msX - 7, msY - 34, msX + 7, msY + 30, cL, cD, cL, cD, 1)
        DrawBox(msX - 7, msY - 22, msX + 7, msY - 12, Col(245, 205, 30, 255), Col(245, 205, 30, 255), Col(245, 205, 30, 255), Col(245, 205, 30, 255), 1)
        FillTri(msX, msY - 64, msX - 7, msY - 34, msX + 7, msY - 34, cR)
    endif
endfunction

function DrawHudBar()
    th as float
    c as integer
    th = ThreatLevel()
    DrawBox(700, 34, 1000, 48, Col(0, 0, 0, 140), Col(0, 0, 0, 140), Col(0, 0, 0, 140), Col(0, 0, 0, 140), 1)
    if th > 0
        c = Col(Trunc(120 + 135 * th), Trunc(220 - 170 * th), 60, 255)
        if th > 0.8 and Sin(animT * 900) > 0
            c = Col(255, 255, 255, 255)
        endif
        DrawBox(702, 36, 702 + 296 * th, 46, c, c, c, c, 1)
    endif
    DrawBox(700, 34, 1000, 48, Col(255, 255, 255, 200), Col(255, 255, 255, 200), Col(255, 255, 255, 200), Col(255, 255, 255, 200), 0)
endfunction
