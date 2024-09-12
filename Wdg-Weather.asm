;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@                                                                            @
;@                      W e a t h e r   F o r e c a s t                       @
;@                          (SymbOS Desktop Widget)                           @
;@             (c) 2016-2016 by Prodatron / SymbiosiS (Jörn Mika)             @
;@                                                                            @
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

;todo
;- forecast datenanalyse
;- download
;- properties
;- error anzeige
;- save properties


prgprz  ld ix,wdgsizt
        ld b,2
prgprz3 push bc
        ld l,(ix+0)
        ld h,(ix+1)
        inc ix:inc ix
        call wdgini
        pop bc
        djnz prgprz3

        call wthact

        ld b,10                 ;wait for first message (max 10 idles)
prgprz1 push bc
        rst #30
        ld a,(App_PrcID)
        db #dd:ld l,a
        db #dd:ld h,-1
        ld iy,App_MsgBuf
        rst #18
        db #dd:dec l
        pop bc
        jr z,prgprz2
        djnz prgprz1
        jr prgend

prgprz0 ld a,(App_PrcID)
        db #dd:ld l,a
        db #dd:ld h,-1
        ld iy,App_MsgBuf
        rst #18
        db #dd:dec l
        jr z,prgprz2
        rst #30
        ld hl,wdgcnt
        dec (hl)
        call z,wdgnxt
        jr prgprz0
prgprz2 ld a,(App_MsgBuf)
        or a
        jr z,prgend
        cp MSR_DSK_WCLICK
        jr z,prgprz4
        cp MSC_WDG_SIZE
        jp z,wdgsiz
        cp MSC_WDG_PROP
        jp z,wdgprp
        cp MSC_WDG_CLICK
        jp z,wdgclk
        jr prgprz0
prgprz4 ld a,(App_MsgBuf+2)
        cp DSK_ACT_CLOSE
        jp z,wdgprp0
        cp DSK_ACT_CONTENT
        jr nz,prgprz0
        ld hl,(App_MsgBuf+8)
        ld a,l
        or h
        jr z,prgprz0
        jp (hl)

;### PRGEND -> End program
prgend  ld hl,(App_BegCode+prgpstnum)
        call SySystem_PRGEND
prgend0 rst #30
        jr prgend0


;==============================================================================
;### WEATHER ROUTINES #########################################################
;==============================================================================

cfgdatbeg
cfgdatend

wdgcnt  db 0

wdgnxt  ld (hl),255
        jp prgprz0

;### WTHACT -> get actual data for display 
wthactt db 0    ;current time in minutes/8
wthactc db 0,0  ;day code, night code

wthact  ;...load CSV from weather api
        ld de,csvbuf
wthact1 ld a,(de)           ;skip comments
        cp "#"
        jr nz,wthact2
        call strlin
        jr wthact1
wthact2 call strtim             ;** CURRENT WEATHER CONDITIONS
        jp c,wthacte        ;read "observation_time"
        ld (wthactt),a
        ld c,1
        call strskp         ;get "temp_C"
        ld a,(de)           ;check sign
        cp "-"
        ld hl,digsgnbmp0
        jr nz,wthact3
        inc de
        ld hl,digsgnbmp1
wthact3 ld (digsgnbmp+3),hl
        ld a,(de)           ;read temperature
        call wthact4
        jp c,wthacte
        ld (digfnthd0+3),hl
        inc de
        ld a,(de)
        cp ","
        ld hl,10*250+digfntbmp
        jr z,wthact6
        call wthact4
        jp c,wthacte
        inc de
wthact6 ld (digfnthd1+3),hl
        ld c,2
        call strskp         ;skip this terminator and "temp_F"
        jp c,wthacte
        call strval         ;get "weatherCode"
        jp c,wthacte
        push de
        call wthcod         ;C=day code, B=night code
        pop de
        jp c,wthacte
        ld (wthactc),bc
        ld c,4
        call strskp         ;skip this terminator, "weatherIconUrl", "weatherDesc" and "windspeedMiles"
        jp c,wthacte
        ld l,e
        ld h,d              ;save "windspeedKmph"
        ld c,2
        call strskp         ;skip "windspeedKmph" and "winddirDegree"
        jp c,wthacte
        push hl
        ld hl,dspwndtxt
        call strcop         ;copy "winddir16Point"
        ld (hl)," "
        inc hl
        ex de,hl
        ex (sp),hl
        ex de,hl
        call strcop         ;copy "windspeedKmph"
        ld de,dspwndtxt0
        call strcop
        ld (hl),0
        pop de
        ld c,2
        call strskp
        jr c,wthacte
        ld hl,dsphumtxt+7
        call strcop         ;copy "humidity"
        ld (hl),"%"
        inc hl
        ld (hl),0
        call strlin

        ld c,5                  ;** DAY INFORMATION
        call strskp         ;skip "date" and "max/mintempC/F"
        jr c,wthacte
        call strtim         ;read "sunrise"
        jr c,wthacte
        push af
        inc de
        call strtim         ;read "sunset"
        pop bc
        jr c,wthacte
        ld c,a              ;B=sunrise, C=sunset
        ld hl,(wthactc)     ;L=day code, H=night code
        ld a,(wthactt)
        cp b
        jr c,wthact7
        cp c
        jr nc,wthact7
        ld h,l
wthact7 ld a,h
        call wthsym         ;set weather symbol
        ld (wthsymhed+3),hl
        call strlin

wthact8 ld c,1                  ;** HOURLY INFORMATION
        call strskp
        jr c,wthacte
        call strval
        jr c,wthacte
        push hl
        ld c,25
        call strskp
        pop hl
        jr c,wthacte
        push hl
        ld hl,dspraitxt+5
        call strcop
        ld (hl),"%"
        inc hl
        ld (hl),0
        pop bc
        push de
        ld de,25
        call clcd16
        sla l
        pop de
        ld a,(wthactt)
        cp l
        jr c,wthact9
        jr z,wthact9
        call strlin
        ld a,(de)
        or a
        jr nz,wthact8

wthact9                     ;...update
        ret

wthacte                     ;...error
        ret

wthact4 sub "0"
        ret c
        cp 9+1
        ccf
        ret c
        or a
        ld l,a
        ld h,a
        jr z,wthact5
        add a
        ld l,a
        add a
        add l
        neg
        ld l,a
        dec h           ;hl=a*250
wthact5 ld bc,digfntbmp
        add hl,bc
        ret


;==============================================================================
;### WIDGET ROUTINES ##########################################################
;==============================================================================

wdgwinid    db 0    ;window ID
wdgctrid    db 0    ;control collection ID

;### WDGINI -> init controls
;### Input      HL=control group
wdgini  ld b,(hl)
        inc hl:inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        inc hl
        ld a,(App_PrcID)
        ld de,16
wdgini1 ld (hl),a
        add hl,de
        djnz wdgini1
        ret

;### WDGSIZ -> size event
wdgsizt dw wdggrpwin0,wdggrpwin1

wdgsiz  ld hl,(App_MsgBuf+1)
        ld (wdgwinid),hl
        ld a,(App_MsgBuf+3)
;        ld e,a
        add a
        ld l,a
        ld h,0
        ld bc,wdgsizt
        add hl,bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        ld (wdgobjsup),bc
;        add a
;        add e
;        ld l,a
;        ld h,0
;        ld bc,timact
;        add hl,bc
;        ld (timactpnt),hl
        ld hl,256*FNC_DXT_WDGOKY+MSR_DSK_EXTDSK
        ld (App_MsgBuf+0),hl
        ld hl,wdgobjsup
        ld (App_MsgBuf+2),hl
        ld a,(App_BnkNum)
        ld (App_MsgBuf+4),a
        ld a,(App_PrcID)
        db #dd:ld l,a
        ld iy,App_MsgBuf
        rst #10
        jp prgprz0

;### WDGPRP -> properties event
wdgprpw db 0
wdgprp
wdgprp0 jp prgprz0

;### WDGCLK -> click event
wdgfrcw db 0

wdgclk  ld a,(App_MsgBuf+3)
        cp DSK_SUB_MDCLICK
        jr z,wdgclk1
        ld a,(wdgfrcw)              ;single click -> open forecast window
        or a
        jp nz,prgprz0
        ;...load data
        ld de,forcstwin
        ld a,(App_BnkNum)
        call SyDesktop_WINOPN
        ld (wdgfrcw),a
        jp prgprz0
wdgclk1 ;...aktualisieren           ;double click -> reload weather data
        jp prgprz0
wdgclk0 ld hl,wdgfrcw               ;close forecast window
        ld a,(hl)
        ld (hl),0
        call SyDesktop_WINCLS
        jp prgprz0


;==============================================================================
;### SUB ROUTINES #############################################################
;==============================================================================

;### CLCDEC -> converts byte into ASCII digits
;### Input      A=value
;### Output     L=10. digit char, H=1.digit char
;### Destroyed  AF
clcdec  ld l,0
clcdec1 sub 10
        jr c,clcdec2
        inc l
        jr clcdec1
clcdec2 add "0"+10
        ld h,a
        ld a,"0"
        add l
        ld l,a
        ret

;### CLCD16 -> division 16bit
;### Input      BC=Wert1, DE=Wert2
;### Output     HL=Wert1/Wert2, DE=Wert1 MOD Wert2
;### Destroyed  AF,BC,DE
clcd16  ld a,e
        or d
        ld hl,0
        ret z
        ld a,b
        ld b,16
clcd161 rl c
        rla
        adc hl,hl
        sbc hl,de
        jr nc,clcd162
        add hl,de
clcd162 djnz clcd161
        rl c
        rla
        cpl
        ld d,a
        ld a,c
        cpl
        ld e,a
        ex de,hl
        ret

;### STRLIN -> skips to next line
;### Input      DE=string pointer
;### Output     DE=string pointer (next line)
;### Destroyed  AF
strlin  ex de,hl
        ld a,13
strlin1 cp (hl)
        inc hl
        jr nz,strlin1
        inc hl
        ex de,hl
        ret

;### STRSKP -> skips entries in a CSV line
;### Input      DE=string pointer, C=number of entries to skip
;### Output     CF=0 -> DE=string pointer, CF=1 -> end of string reached
;### Destroyed  AF,C
strskp  ld a,(de)
        cp 13
        scf
        ret z
        inc de
        cp ","
        jr nz,strskp
        dec c
        jr nz,strskp
        ret

;### STRWHT -> skips white spaces (space and tab)
;### Input      DE=string pointer
;### Output     DE=new string pointer
;### Destroyed  AF
strwht  ld a,(de)
        cp 32
        jr z,strwht1
        cp 9
        ret nz
strwht1 inc de
        jr strwht

;### STRVAL -> converts string to signed number (16bit)
;### Input      DE=string (terminated by , or 13; white spaces before and behind number are accepted)
;### Output     CF=0 -> HL=number, DE=string position at terminator
;###            CF=1 -> format error
;### Destroyed  AF,BC
strvals db 0            ;0=signed
strval  call strwht     ;skip white spaces
        ld hl,0
        ld a,(de)
        sub "-"
        ld (strvals),a
        jr nz,strval1
        inc de
strval1 ld a,(de)
        cp "9"+1
        ccf
        ret c
        sub "0"
        jr c,strval2
        add hl,hl
        ld c,l:ld b,h
        add hl,hl
        add hl,hl
        add hl,bc
        ld c,a
        ld b,0
        add hl,bc
        inc de
        jr strval1
strval2 cp 32-"0"
        jr z,strval3
        cp 9-"0"
        jr nz,strval4
strval3 call strwht
strval4 cp ","-"0"
        jr z,strval5
        cp 13-"0"
        jr z,strval5
        scf
        ret
strval5 ld a,(strvals)
        or a
        ret nz
        ld a,l
        cpl
        ld l,a
        ld a,h
        cpl
        ld h,a
        inc hl
        ret

;### STRCOP -> copies CSV string to destination
;### Input      DE=string pointer, HL=destination
;### Output     DE=string pointer (at terminator), HL=behind copied string
;### Destroyed  AF
strcop  ld a,(de)
        or a
        ret z
        cp ","
        ret z
        cp 13
        ret z
        ex de,hl
        ldi
        ex de,hl
        jr strcop

;### STRTIM -> converts string to a timestamp
;### Input      DE=string pointer (hh;mm xM)
;### Output     CF=0 -> C=minutes, B=seconds, A=minutes/8 since 00;00, L=AM(0)/PM(12), DE=string pointer (at terminator)
;###            CF=1 -> format error
;### Destroyed  F
strtim  call strtim0
        ret c
        ld b,a
        ld a,(de)
        cp ":"
        scf
        ret nz
        inc de
        call strtim0
        ret c
        ld c,a
        ld a,(de)
        cp " "
        scf
        ret nz
        inc de
        ld l,0
        ld a,(de)
        cp "A"
        jr z,strtim2
        cp "P"
        scf
        ret nz
        ld l,12
strtim2 ld a,b          ;B=hour (1-12), C=minute, L=am(0)/pm(12)
        cp 12
        jr nz,strtim3
        xor a
strtim3 add l
        ld b,a          ;B=hour (0-23)
        inc de
        ld a,(de)
        cp "M"
        scf
        ret nz
        inc de
        ld a,c          ;00mmmmmm
        and #38         ;00mmm000
        add a
        add a           ;mmm00000
        or b            ;mmmhhhhh
        rlca:rlca:rlca  ;hhhhhmmm
        or a
        ret
strtim0 call strtim1    ;A=(DE+0)*10+(DE+1), DE=DE+2, CF=1 error
        ret c
        add a
        ld c,a
        add a
        add a
        add c
        ld c,a
        call strtim1
        ret c
        add c
        ret
strtim1 ld a,(de)
        inc de
        sub "0"
        ret c
        cp 9+1
        ccf
        ret

;### TIMGDY -> calculates weekday
;### Input      D=day (1-x), E=month (1-x), HL=year
;### Output     A=weekday (0-6; 0=monday)
;### Destroyed  F,BC,DE,HL
timgdyn db 0,3,3,6,1,4,6,2,5,0,3,5
timgdys db 0,3,4,0,2,5,0,3,6,1,4,6
timgdy  ld bc,1980
        or a
        sbc hl,bc
        ld b,l          ;B=Jahre seit 1980
        ld c,3          ;A=Schaltjahr-Checker
        ld a,1          ;A=Wochentag (01.01.1980 war Dienstag)
        inc b
timgdy1 dec b
        jr z,timgdy3
        inc a           ;neues Jahr -> Wochentag+1
        inc c
        bit 2,c
        jr z,timgdy2
        ld c,0          ;Schaltjahr -> Wochentag+2
        inc a
timgdy2 cp 7
        jr c,timgdy1
        sub 7
        jr timgdy1
timgdy3 ld b,a          ;B=Wochentag vom 1.1. des Jahres
        ld a,c
        cp 3
        ld hl,timgdyn
        jr nz,timgdy4
        ld hl,timgdys
timgdy4 ld a,d
        dec a
        ld d,0
        dec e
        add hl,de
        add (hl)
        add b
timgdy5 sub 7
        jr nc,timgdy5
        add 7
        ret


;### WTHCOD -> finds weather code
;### Input      HL=WORLDWEATHERONLINE.COM api weather code
;### Output     CF=0 -> C=widget code day, B=widget code night
;###            CF=1 -> unknown weather code
;### Destroyed  AF,DE,HL
wthcod  ex de,hl
        ld hl,wthcodtab
        ld b,wthcodtab0-wthcodtab/4
wthcod1 ld a,e
        cp (hl)
        inc hl
        jr nz,wthcod2
        ld a,d
        cp (hl)
        jr nz,wthcod2
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        ret
wthcod2 inc hl:inc hl:inc hl
        djnz wthcod1
        scf
        ret

;### WTHSYM -> get weather symbol
;### Input      A=widget weather code
;### Output     HL=symbol bitmap address
;### Destroyed  AF,BC
wthsym  add a
        ld h,a
        ld l,0
        ld bc,wthsymbmp
        add hl,bc
        ret

;0=klar, 1=leicht bewölkt, 2=bewölkt, 3=bedeckt, 4=regen, 5=regen mit sonne, 6=gewitter, 7=schnee
;9       9                 8          8          10       10                 10          11
;8=nacht/bewölkt, 9=nacht/klar, 10=nacht/regen, 11=nacht/schnee

wthcodtab
dw 395,11*256+07  ;Moderate or heavy snow in area with thunder
dw 392,11*256+07  ;Patchy light snow in area with thunder
dw 389,10*256+06  ;Moderate or heavy rain in area with thunder
dw 386,10*256+06  ;Patchy light rain in area with thunder
dw 377,11*256+07  ;Moderate or heavy showers of ice pellets
dw 374,11*256+07  ;Light showers of ice pellets
dw 371,11*256+07  ;Moderate or heavy snow showers
dw 368,11*256+07  ;Light snow showers
dw 365,10*256+04  ;Moderate or heavy sleet showers
dw 362,11*256+07  ;Light sleet showers
dw 359,10*256+04  ;Torrential rain shower
dw 356,10*256+04  ;Moderate or heavy rain shower
dw 353,10*256+05  ;Light rain shower
dw 350,11*256+07  ;Ice pellets
dw 338,11*256+07  ;Heavy snow
dw 335,11*256+07  ;Patchy heavy snow
dw 332,11*256+07  ;Moderate snow
dw 329,11*256+07  ;Patchy moderate snow
dw 326,11*256+07  ;Light snow
dw 323,11*256+07  ;Patchy light snow
dw 320,11*256+07  ;Moderate or heavy sleet
dw 317,11*256+07  ;Light sleet
dw 314,10*256+04  ;Moderate or Heavy freezing rain
dw 311,10*256+05  ;Light freezing rain
dw 308,10*256+04  ;Heavy rain
dw 305,10*256+05  ;Heavy rain at times
dw 302,10*256+04  ;Moderate rain
dw 299,10*256+05  ;Moderate rain at times
dw 296,10*256+05  ;Light rain
dw 293,10*256+05  ;Patchy light rain
dw 284,10*256+04  ;Heavy freezing drizzle
dw 281,10*256+04  ;Freezing drizzle
dw 266,10*256+05  ;Light drizzle
dw 263,10*256+05  ;Patchy light drizzle
dw 260,08*256+03  ;Freezing fog
dw 248,08*256+03  ;Fog
dw 230,11*256+07  ;Blizzard
dw 227,11*256+07  ;Blowing snow
dw 200,10*256+06  ;Thundery outbreaks in nearby
dw 185,10*256+04  ;Patchy freezing drizzle nearby
dw 182,10*256+05  ;Patchy sleet nearby
dw 179,11*256+07  ;Patchy snow nearby
dw 176,10*256+05  ;Patchy rain nearby
dw 143,08*256+03  ;Mist
dw 122,08*256+03  ;Overcast
dw 119,08*256+02  ;Cloudy
dw 116,09*256+01  ;Partly Cloudy
dw 113,09*256+00  ;Clear/Sunny
wthcodtab0

wthurlday   db "http://api.worldweatheronline.com/free/v2/weather.ashx?key=840eb8af68a3630f7fd76b9313614&num_of_days=1&tp=3&format=csv&q=CITY"
wthurlwek   db "http://api.worldweatheronline.com/free/v2/weather.ashx?key=840eb8af68a3630f7fd76b9313614&num_of_days=7&tp=24&format=csv&q=CITY"

csvbuf
db "#The CSV format is in following way:-",13,10
db "#First row contains the current weather condition. If for any reason we do not have current condition it will have 'Not Available'.",13,10
db "#The current weather condition data is laid in the following way:-",13,10
db "#observation_time,temp_C,temp_F,weatherCode,weatherIconUrl,weatherDesc,windspeedMiles,windspeedKmph,winddirDegree,winddir16Point,precipMM,humidity,visibilityKm,pressureMB,cloudcover",13,10
db "#",13,10
db "#The day information is available in following format:-",13,10
db "#date,maxtempC,maxtempF,mintempC,mintempF,sunrise,sunset,moonrise,moonset",13,10
db "#",13,10
db "#Hourly information follows below the day in the following way:-",13,10
db "#date,time,tempC,tempF,windspeedMiles,windspeedKmph,winddirdegree,winddir16point,weatherCode,weatherIconUrl,weatherDesc,precipMM,humidity,visibilityKm,pressureMB,cloudcover,HeatIndexC,HeatIndexF,"
    db "DewPointC,DewPointF,WindChillC,WindChillF,WindGustMiles,WindGustKmph,FeelsLikeC,FeelsLikeF,chanceofrain,chanceofremdry,chanceofwindy,chanceofovercast,chanceofsunshine,chanceoffrost,chanceofhightemp,chanceoffog,chanceofsnow,chanceofthunder",13,10
db "#",13,10
db "07:26 PM,21,70,113,http://cdn.worldweatheronline.net/images/wsymbols01_png_64/wsymbol_0008_clear_sky_night.png,Clear ,6,9,340,NNW,0.0,69,8,1022,0",13,10
db "2016-08-13,26,78,17,62,06:17 AM,08:56 PM,05:10 PM,01:31 AM",13,10
db "2016-08-13,100,15,60,6,9,198,SSW,143,http://cdn.worldweatheronline.net/images/wsymbols01_png_64/wsymbol_0006_mist.png,Mist,0.0,96,2,1024,41,16,61,16,60,16,61,15,23,16,61,0,0,0,0,88,0,0,0,0,0",13,10
db "2016-08-13,400,15,58,5,8,186,S,143,http://cdn.worldweatheronline.net/images/wsymbols01_png_64/wsymbol_0006_mist.png,Mist,0.0,96,2,1023,19,15,59,14,58,15,58,12,19,15,58,0,0,0,0,97,0,0,0,0,0",13,10
db "2016-08-13,700,15,60,5,8,187,S,113,http://cdn.worldweatheronline.net/images/wsymbols01_png_64/wsymbol_0001_sunny.png,Sunny,0.0,89,10,1023,7,18,65,16,61,18,65,7,12,18,65,0,0,0,0,96,0,0,0,0,0",13,10
db "2016-08-13,1000,22,71,8,13,264,W,113,http://cdn.worldweatheronline.net/images/wsymbols01_png_64/wsymbol_0001_sunny.png,Sunny,0.0,67,10,1023,4,25,76,16,60,22,72,12,19,22,72,0,0,0,0,99,0,0,0,0,0",13,10
db "2016-08-13,1300,25,77,10,16,272,W,113,http://cdn.worldweatheronline.net/images/wsymbols01_png_64/wsymbol_0001_sunny.png,Sunny,0.0,60,10,1022,2,26,79,17,62,25,76,14,22,26,79,0,0,0,0,98,0,15,0,0,0",13,10
db "2016-08-13,1600,26,78,11,17,275,W,113,http://cdn.worldweatheronline.net/images/wsymbols01_png_64/wsymbol_0001_sunny.png,Sunny,0.0,64,10,1021,10,26,79,17,63,25,76,13,20,26,79,0,0,0,0,97,0,19,0,0,0",13,10
db "2016-08-13,1900,24,74,9,14,292,WNW,116,http://cdn.worldweatheronline.net/images/wsymbols01_png_64/wsymbol_0002_sunny_intervals.png,Partly Cloudy ,0.0,80,10,1022,44,24,76,18,64,21,70,8,13,24,76,0,0,0,0,37,0,0,0,0,0",13,10
db "2016-08-13,2200,19,66,6,9,334,NNW,116,http://cdn.worldweatheronline.net/images/wsymbols01_png_64/wsymbol_0004_black_low_cloud.png,Partly Cloudy ,0.0,90,10,1023,43,16,62,15,59,16,62,8,13,16,62,0,0,0,0,10,0,0,0,0,0",13,10
db 0


;==============================================================================
;### DATA AREA ################################################################
;==============================================================================

App_BegData


wthsymhed db 16,32,32:dw 00*512+wthsymbmp,wthsymenc,16*384
wthsm1hed db 16,32,32:dw 01*512+wthsymbmp,wthsymenc,16*384
wthsm2hed db 16,32,32:dw 02*512+wthsymbmp,wthsymenc,16*384
wthsm3hed db 16,32,32:dw 03*512+wthsymbmp,wthsymenc,16*384
wthsm4hed db 16,32,32:dw 04*512+wthsymbmp,wthsymenc,16*384
wthsm5hed db 16,32,32:dw 05*512+wthsymbmp,wthsymenc,16*384
wthsm6hed db 16,32,32:dw 06*512+wthsymbmp,wthsymenc,16*384

wthsymenc db 5
wthsymbmp
;00
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#72,#27,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#72,#27,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#7C,#C7,#77,#72,#27,#77,#7C,#C7,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#CC,#77,#72,#27,#77,#CC,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#CC,#77,#77,#77,#77,#CC,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#C7,#77,#77,#77,#77,#77
db #77,#77,#22,#27,#77,#77,#7C,#CC,#CC,#77,#77,#77,#72,#27,#77,#77
db #77,#77,#72,#22,#77,#77,#CC,#CC,#CC,#CC,#77,#72,#22,#27,#77,#77
db #77,#77,#77,#72,#77,#7C,#CC,#CC,#CC,#CC,#C7,#72,#27,#77,#77,#77
db #77,#77,#77,#77,#77,#CC,#CC,#CC,#CC,#CC,#CC,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#7C,#CC,#CC,#CC,#CC,#CC,#CC,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#7C,#CC,#CC,#CC,#CC,#CC,#CC,#77,#77,#77,#77,#77
db #77,#7C,#CC,#CC,#77,#CC,#CC,#CC,#CC,#CC,#CC,#C7,#CC,#CC,#77,#77
db #77,#7C,#CC,#C7,#7C,#CC,#CC,#CC,#CC,#CC,#CC,#77,#7C,#CC,#77,#77
db #77,#77,#77,#77,#7C,#CC,#CC,#CC,#CC,#CC,#CC,#C7,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#CC,#CC,#CC,#CC,#CC,#CC,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#CC,#CC,#CC,#CC,#CC,#C7,#72,#77,#77,#77,#77
db #77,#77,#77,#22,#27,#7C,#CC,#CC,#CC,#CC,#C7,#72,#22,#77,#77,#77
db #77,#77,#72,#27,#77,#77,#CC,#CC,#CC,#C7,#77,#77,#22,#27,#77,#77
db #77,#77,#72,#77,#77,#77,#77,#77,#C7,#77,#77,#77,#77,#27,#77,#77
db #77,#77,#77,#77,#77,#7C,#77,#77,#77,#77,#C7,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#CC,#77,#72,#77,#77,#CC,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#7C,#C7,#77,#72,#27,#77,#7C,#C7,#77,#77,#77,#77
db #77,#77,#77,#77,#7C,#C7,#77,#72,#27,#77,#7C,#C7,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#72,#27,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
;01
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#7C,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#CC,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#CC,#77,#77,#CC,#77,#77,#77
db #77,#77,#77,#77,#78,#88,#88,#87,#77,#CC,#77,#7C,#CC,#77,#77,#77
db #77,#77,#77,#77,#88,#88,#88,#88,#77,#C7,#77,#7C,#C7,#77,#77,#77
db #77,#77,#77,#78,#88,#88,#88,#88,#87,#77,#77,#7C,#77,#77,#77,#77
db #77,#77,#77,#88,#88,#88,#88,#88,#88,#77,#77,#77,#77,#77,#CC,#77
db #77,#77,#78,#88,#88,#88,#88,#88,#88,#77,#77,#77,#77,#7C,#CC,#77
db #77,#77,#88,#88,#88,#88,#88,#88,#88,#88,#87,#77,#77,#CC,#77,#77
db #77,#88,#88,#88,#88,#88,#88,#88,#88,#88,#88,#77,#77,#77,#77,#77
db #78,#88,#88,#88,#88,#88,#88,#88,#88,#88,#88,#87,#77,#77,#77,#77
db #88,#88,#88,#88,#88,#88,#88,#88,#88,#88,#88,#88,#77,#77,#77,#77
db #88,#88,#88,#88,#88,#88,#88,#88,#88,#88,#88,#88,#77,#77,#CC,#CC
db #88,#88,#88,#88,#88,#88,#88,#88,#88,#88,#88,#87,#77,#7C,#CC,#CC
db #88,#88,#88,#88,#88,#88,#88,#88,#88,#88,#88,#88,#77,#77,#77,#77
db #78,#88,#88,#88,#88,#88,#88,#88,#88,#88,#88,#87,#77,#77,#77,#77
db #77,#88,#88,#88,#88,#88,#88,#88,#88,#88,#88,#77,#77,#77,#77,#77
db #77,#77,#87,#87,#87,#87,#87,#87,#87,#87,#77,#77,#77,#CC,#C7,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#7C,#CC,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#7C,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#7C,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#7C,#C7,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#CC,#77,#77,#CC,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#CC,#77,#77,#CC,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#CC,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#CC,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
;02
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#71,#71,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#71,#18,#18,#11,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#71,#18,#88,#88,#88,#17,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#71,#88,#88,#88,#88,#81,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#18,#88,#88,#88,#88,#81,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#71,#88,#88,#88,#88,#88,#88,#17,#77,#77,#77,#77
db #77,#77,#77,#71,#18,#88,#88,#88,#88,#88,#88,#81,#11,#77,#77,#77
db #77,#77,#71,#18,#88,#88,#88,#88,#88,#88,#88,#88,#81,#77,#77,#77
db #77,#77,#71,#88,#88,#88,#88,#88,#88,#88,#88,#88,#88,#17,#77,#77
db #77,#77,#71,#88,#88,#88,#88,#88,#88,#88,#88,#88,#88,#81,#77,#77
db #77,#77,#18,#88,#88,#88,#88,#88,#88,#88,#88,#88,#88,#81,#77,#77
db #77,#77,#18,#88,#88,#88,#88,#88,#88,#88,#88,#88,#88,#81,#77,#77
db #77,#77,#71,#88,#88,#88,#88,#88,#88,#88,#88,#88,#88,#81,#77,#77
db #77,#77,#71,#88,#88,#88,#88,#88,#88,#88,#88,#88,#88,#17,#77,#77
db #77,#77,#77,#11,#88,#88,#88,#88,#88,#88,#88,#88,#11,#77,#77,#77
db #77,#77,#77,#77,#11,#11,#11,#11,#11,#11,#11,#11,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
;03
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#71,#17,#17,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#71,#11,#11,#17,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#11,#DD,#DD,#11,#17,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#71,#1D,#DD,#DD,#DD,#11,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#71,#DD,#DD,#DD,#DD,#D1,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#11,#DD,#DD,#DD,#DD,#D1,#17,#77,#77,#77,#77
db #77,#77,#77,#71,#11,#11,#DD,#DD,#DD,#DD,#DD,#11,#11,#77,#77,#77
db #77,#77,#77,#11,#DD,#11,#1D,#DD,#DD,#DD,#D1,#1D,#11,#17,#77,#77
db #77,#77,#71,#1D,#DD,#DD,#DD,#DD,#DD,#DD,#D1,#1D,#D1,#17,#77,#77
db #77,#77,#71,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#11,#77,#77
db #77,#77,#71,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#11,#77,#77
db #77,#77,#71,#1D,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#17,#77,#77
db #77,#77,#77,#11,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#D1,#17,#77,#77
db #77,#77,#77,#11,#1D,#DD,#DD,#DD,#DD,#DD,#1D,#1D,#11,#77,#77,#77
db #77,#77,#77,#77,#11,#11,#1D,#DD,#DD,#DD,#11,#11,#17,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
;04
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#71,#17,#17,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#71,#11,#11,#17,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#11,#DD,#DD,#11,#17,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#71,#1D,#DD,#DD,#DD,#11,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#71,#DD,#DD,#DD,#DD,#D1,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#11,#DD,#DD,#DD,#DD,#D1,#17,#77,#77,#77,#77
db #77,#77,#77,#71,#11,#11,#DD,#DD,#DD,#DD,#DD,#11,#11,#77,#77,#77
db #77,#77,#77,#11,#DD,#11,#1D,#DD,#DD,#DD,#D1,#1D,#11,#17,#77,#77
db #77,#77,#71,#1D,#DD,#DD,#DD,#DD,#DD,#DD,#D1,#1D,#D1,#17,#77,#77
db #77,#77,#71,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#11,#77,#77
db #77,#77,#71,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#11,#77,#77
db #77,#77,#71,#1D,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#17,#77,#77
db #77,#77,#77,#11,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#D1,#17,#77,#77
db #77,#77,#77,#11,#1D,#DD,#DD,#DD,#DD,#DD,#1D,#1D,#11,#77,#77,#77
db #77,#77,#77,#77,#11,#11,#1D,#DD,#DD,#DD,#11,#11,#17,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#74,#74,#74,#74,#74,#74,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#74,#74,#74,#74,#74,#74,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#74,#74,#74,#74,#74,#74,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#74,#74,#74,#74,#74,#74,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
;05
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#27,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#72,#27,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#72,#27,#77,#7C,#C7,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#72,#27,#77,#CC,#C7,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#71,#11,#72,#77,#77,#CC,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#11,#D1,#17,#77,#77,#C7,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#71,#1D,#DD,#11,#77,#77,#77,#77,#72,#27,#77
db #77,#77,#77,#77,#77,#71,#DD,#DD,#D1,#11,#77,#77,#77,#22,#27,#77
db #77,#77,#77,#77,#77,#11,#DD,#DD,#DD,#D1,#11,#77,#72,#27,#77,#77
db #77,#77,#77,#71,#11,#11,#DD,#DD,#DD,#DD,#D1,#17,#77,#77,#77,#77
db #77,#77,#77,#11,#DD,#11,#1D,#DD,#DD,#DD,#DD,#17,#77,#77,#77,#77
db #77,#77,#71,#1D,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#11,#77,#77,#77,#77
db #77,#77,#71,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#D1,#77,#7C,#CC,#C7
db #77,#77,#71,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#11,#77,#CC,#CC,#C7
db #77,#77,#71,#1D,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#D1,#77,#77,#77,#77
db #77,#77,#77,#11,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#11,#77,#77,#77,#77
db #77,#77,#77,#11,#1D,#DD,#DD,#DD,#DD,#DD,#11,#17,#77,#77,#77,#77
db #77,#77,#77,#77,#11,#11,#1D,#DD,#DD,#DD,#17,#77,#72,#22,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#22,#27,#77
db #77,#77,#77,#77,#77,#74,#74,#74,#74,#74,#77,#77,#77,#77,#27,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#C7,#77,#77,#77,#77
db #77,#77,#77,#77,#74,#74,#74,#74,#74,#77,#77,#CC,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#72,#27,#77,#7C,#C7,#77,#77,#77
db #77,#77,#77,#74,#74,#74,#74,#74,#72,#27,#77,#7C,#C7,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#72,#27,#77,#77,#77,#77,#77,#77
db #77,#77,#74,#74,#74,#74,#74,#74,#72,#27,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
;06
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#71,#17,#17,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#71,#11,#11,#17,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#11,#DD,#DD,#11,#17,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#71,#1D,#DD,#DD,#DD,#11,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#71,#DD,#DD,#DD,#DD,#D1,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#11,#DD,#DD,#DD,#DD,#D1,#17,#77,#77,#77,#77
db #77,#77,#77,#71,#11,#11,#DD,#DD,#DD,#DD,#DD,#11,#11,#77,#77,#77
db #77,#77,#77,#11,#DD,#11,#1D,#DD,#DD,#DD,#D1,#1D,#11,#17,#77,#77
db #77,#77,#71,#1D,#DD,#DD,#DD,#DD,#CC,#CD,#D1,#1D,#D1,#17,#77,#77
db #77,#77,#71,#DD,#DD,#DD,#DD,#DC,#CC,#DD,#DD,#DD,#DD,#11,#77,#77
db #77,#77,#71,#DD,#DD,#DD,#DD,#CC,#CD,#DD,#DD,#DD,#DD,#11,#77,#77
db #77,#77,#71,#1D,#DD,#DD,#DC,#CC,#DD,#DD,#DD,#DD,#DD,#17,#77,#77
db #77,#77,#77,#11,#DD,#DD,#CC,#CD,#DD,#DD,#DD,#DD,#D1,#17,#77,#77
db #77,#77,#77,#11,#1D,#DD,#DC,#CC,#DD,#DD,#1D,#1D,#11,#77,#77,#77
db #77,#77,#77,#77,#11,#11,#1D,#CC,#CD,#DD,#11,#11,#17,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#7C,#CC,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#74,#74,#74,#CC,#C4,#74,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#7C,#CC,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#74,#74,#74,#CC,#C4,#74,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#7C,#CC,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#74,#74,#74,#CC,#C4,#74,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#7C,#CC,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#74,#74,#74,#CC,#C4,#74,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#7C,#CC,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#CC,#C7,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#CC,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
;07
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#71,#17,#17,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#71,#11,#11,#17,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#11,#DD,#DD,#11,#17,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#71,#1D,#DD,#DD,#DD,#11,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#71,#DD,#DD,#DD,#DD,#D1,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#11,#DD,#DD,#DD,#DD,#D1,#17,#77,#77,#77,#77
db #77,#77,#77,#71,#11,#11,#DD,#DD,#DD,#DD,#DD,#11,#11,#77,#77,#77
db #77,#77,#77,#11,#DD,#11,#1D,#DD,#DD,#DD,#D1,#1D,#11,#17,#77,#77
db #77,#77,#71,#1D,#DD,#DD,#DD,#DD,#DD,#DD,#D1,#1D,#D1,#17,#77,#77
db #77,#77,#71,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#11,#77,#77
db #77,#77,#71,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#11,#77,#77
db #77,#77,#71,#1D,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#17,#77,#77
db #77,#77,#77,#11,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#DD,#D1,#17,#77,#77
db #77,#77,#77,#11,#1D,#DD,#DD,#DD,#DD,#DD,#1D,#1D,#11,#77,#77,#77
db #77,#77,#77,#77,#11,#11,#1D,#DD,#DD,#DD,#11,#11,#17,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#47,#47,#77,#77,#77,#77,#77,#77,#77,#47,#47,#77,#77
db #77,#77,#77,#74,#77,#77,#77,#77,#77,#77,#77,#77,#74,#77,#77,#77
db #77,#77,#47,#74,#77,#47,#77,#77,#77,#77,#77,#47,#74,#77,#47,#77
db #77,#77,#74,#44,#44,#77,#77,#74,#74,#77,#77,#74,#44,#44,#77,#77
db #77,#77,#47,#74,#77,#47,#77,#77,#47,#77,#77,#47,#74,#77,#47,#77
db #77,#77,#77,#74,#77,#77,#74,#77,#47,#74,#77,#77,#74,#77,#77,#77
db #77,#77,#77,#47,#47,#77,#77,#44,#44,#47,#77,#77,#47,#47,#77,#77
db #77,#77,#77,#77,#77,#77,#74,#77,#47,#74,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#47,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#74,#74,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
;08
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#72,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#22,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#72,#22,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#22,#22,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#22,#22,#27,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#22,#22,#27,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#22,#22,#22,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#22,#22,#22,#27,#77,#77,#71,#71,#77,#77,#77,#77,#77,#77,#77
db #77,#22,#22,#22,#22,#22,#71,#11,#11,#11,#77,#77,#77,#77,#77,#77
db #77,#72,#22,#22,#22,#22,#22,#22,#11,#11,#17,#77,#77,#77,#77,#77
db #77,#77,#22,#22,#22,#22,#22,#21,#11,#11,#11,#77,#77,#77,#77,#77
db #77,#77,#72,#22,#22,#22,#22,#11,#11,#11,#11,#77,#77,#77,#77,#77
db #77,#77,#77,#22,#22,#22,#21,#11,#11,#11,#11,#17,#77,#77,#77,#77
db #77,#77,#77,#71,#11,#11,#11,#11,#11,#11,#11,#11,#11,#77,#77,#77
db #77,#77,#71,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#77,#77,#77
db #77,#77,#71,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#17,#77,#77
db #77,#77,#71,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#77,#77
db #77,#77,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#77,#77
db #77,#77,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#77,#77
db #77,#77,#71,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#77,#77
db #77,#77,#71,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#17,#77,#77
db #77,#77,#77,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#77,#77,#77
db #77,#77,#77,#77,#11,#11,#11,#11,#11,#11,#11,#11,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
;09
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#22,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#22,#22,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#72,#22,#27,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#22,#22,#27,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#72,#22,#22,#27,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#22,#22,#22,#27,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#22,#22,#22,#27,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#72,#22,#22,#22,#27,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#72,#22,#22,#22,#27,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#22,#22,#22,#22,#27,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#22,#22,#22,#22,#22,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#22,#22,#22,#22,#22,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#22,#22,#22,#22,#22,#27,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#22,#22,#22,#22,#22,#27,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#22,#22,#22,#22,#22,#22,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#22,#22,#22,#22,#22,#22,#27,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#22,#22,#22,#22,#22,#22,#22,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#22,#22,#22,#22,#22,#22,#22,#27,#77,#77,#77,#77,#77,#77,#77
db #77,#72,#22,#22,#22,#22,#22,#22,#22,#27,#77,#77,#77,#77,#77,#77
db #77,#72,#22,#22,#22,#22,#22,#22,#22,#22,#22,#77,#77,#77,#22,#27
db #77,#72,#22,#22,#22,#22,#22,#22,#22,#22,#22,#22,#22,#22,#22,#27
db #77,#77,#22,#22,#22,#22,#22,#22,#22,#22,#22,#22,#22,#22,#22,#77
db #77,#77,#72,#22,#22,#22,#22,#22,#22,#22,#22,#22,#22,#22,#27,#77
db #77,#77,#77,#22,#22,#22,#22,#22,#22,#22,#22,#22,#22,#22,#77,#77
db #77,#77,#77,#72,#22,#22,#22,#22,#22,#22,#22,#22,#22,#27,#77,#77
db #77,#77,#77,#77,#22,#22,#22,#22,#22,#22,#22,#22,#22,#77,#77,#77
db #77,#77,#77,#77,#72,#22,#22,#22,#22,#22,#22,#22,#27,#77,#77,#77
db #77,#77,#77,#77,#77,#72,#22,#22,#22,#22,#22,#27,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
;10
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#72,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#22,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#72,#22,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#22,#22,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#22,#22,#27,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#22,#22,#27,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#22,#22,#22,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#22,#22,#22,#27,#77,#77,#71,#71,#77,#77,#77,#77,#77,#77,#77
db #77,#22,#22,#22,#22,#22,#71,#11,#11,#11,#77,#77,#77,#77,#77,#77
db #77,#72,#22,#22,#22,#22,#22,#22,#11,#11,#17,#77,#77,#77,#77,#77
db #77,#77,#22,#22,#22,#22,#22,#21,#11,#11,#11,#77,#77,#77,#77,#77
db #77,#77,#72,#22,#22,#22,#22,#11,#11,#11,#11,#77,#77,#77,#77,#77
db #77,#77,#77,#22,#22,#22,#21,#11,#11,#11,#11,#17,#77,#77,#77,#77
db #77,#77,#77,#71,#11,#11,#11,#11,#11,#11,#11,#11,#11,#77,#77,#77
db #77,#77,#71,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#77,#77,#77
db #77,#77,#71,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#17,#77,#77
db #77,#77,#71,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#77,#77
db #77,#77,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#77,#77
db #77,#77,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#77,#77
db #77,#77,#71,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#77,#77
db #77,#77,#71,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#17,#77,#77
db #77,#77,#77,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#77,#77,#77
db #77,#77,#77,#77,#11,#11,#11,#11,#11,#11,#11,#11,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#74,#74,#74,#74,#74,#74,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#74,#74,#74,#74,#74,#74,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#74,#74,#74,#74,#74,#74,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
;11
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#72,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#22,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#72,#22,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#22,#22,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#22,#22,#27,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#22,#22,#27,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#22,#22,#22,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
db #77,#22,#22,#22,#27,#77,#77,#71,#71,#77,#77,#77,#77,#77,#77,#77
db #77,#22,#22,#22,#22,#22,#71,#11,#11,#11,#77,#77,#77,#77,#77,#77
db #77,#72,#22,#22,#22,#22,#22,#22,#11,#11,#17,#77,#77,#77,#77,#77
db #77,#77,#22,#22,#22,#22,#22,#21,#11,#11,#11,#77,#77,#77,#77,#77
db #77,#77,#72,#22,#22,#22,#22,#11,#11,#11,#11,#77,#77,#77,#77,#77
db #77,#77,#77,#22,#22,#22,#21,#11,#11,#11,#11,#17,#77,#77,#77,#77
db #77,#77,#77,#71,#11,#11,#11,#11,#11,#11,#11,#11,#11,#77,#77,#77
db #77,#77,#71,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#77,#77,#77
db #77,#77,#71,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#17,#77,#77
db #77,#77,#71,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#77,#77
db #77,#77,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#77,#77
db #77,#77,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#77,#77
db #77,#77,#71,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#77,#77
db #77,#77,#71,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#17,#77,#77
db #77,#77,#77,#41,#41,#11,#11,#11,#11,#11,#11,#11,#41,#47,#77,#77
db #77,#77,#77,#74,#11,#11,#11,#11,#11,#11,#11,#11,#74,#77,#77,#77
db #77,#77,#47,#74,#77,#47,#77,#74,#74,#77,#77,#47,#74,#77,#47,#77
db #77,#77,#74,#44,#44,#77,#77,#77,#47,#77,#77,#74,#44,#44,#77,#77
db #77,#77,#47,#74,#77,#47,#74,#77,#47,#74,#77,#47,#74,#77,#47,#77
db #77,#77,#77,#74,#77,#77,#77,#44,#44,#47,#77,#77,#74,#77,#77,#77
db #77,#77,#77,#47,#47,#77,#74,#77,#47,#74,#77,#77,#47,#47,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#47,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#74,#74,#77,#77,#77,#77,#77,#77,#77
db #77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77



digfnthd0 db 10,20,25:dw  2*250+digfntbmp,digfntenc,11*250
digfnthd1 db 10,20,25:dw  3*250+digfntbmp,digfntenc,11*250

digfntenc db 5
digfntbmp
;0
db #11,#11,#68,#88,#88,#88,#88,#88,#88,#61, #11,#18,#16,#88,#88,#88,#88,#88,#86,#61, #11,#18,#81,#88,#88,#88,#88,#88,#16,#86, #11,#18,#86,#18,#88,#88,#88,#81,#68,#81, #11,#18,#88,#61,#11,#11,#11,#16,#88,#81
db #11,#18,#88,#61,#11,#11,#11,#18,#88,#81, #11,#68,#88,#61,#11,#11,#11,#18,#88,#81, #11,#68,#88,#61,#11,#11,#11,#18,#88,#61, #11,#68,#88,#61,#11,#11,#11,#18,#88,#61, #11,#68,#88,#11,#11,#11,#11,#18,#88,#61
db #11,#18,#61,#11,#11,#11,#11,#11,#88,#11, #11,#16,#11,#11,#11,#11,#11,#11,#11,#11, #11,#11,#11,#11,#11,#11,#11,#11,#11,#11, #11,#18,#11,#11,#11,#11,#11,#11,#81,#11, #11,#88,#81,#11,#11,#11,#11,#16,#88,#11
db #11,#88,#86,#11,#11,#11,#11,#68,#88,#11, #11,#88,#86,#11,#11,#11,#11,#88,#88,#11, #16,#88,#86,#11,#11,#11,#11,#88,#88,#11, #16,#88,#86,#11,#11,#11,#11,#88,#86,#11, #16,#88,#86,#11,#11,#11,#11,#88,#86,#11
db #16,#88,#81,#11,#11,#11,#11,#88,#86,#11, #16,#88,#16,#88,#88,#88,#86,#18,#86,#11, #16,#81,#68,#88,#88,#88,#88,#61,#86,#11, #16,#16,#88,#88,#88,#88,#88,#86,#66,#11, #11,#68,#88,#88,#88,#88,#88,#88,#11,#11
;1
db #11,#11,#11,#11,#11,#11,#11,#11,#11,#11, #11,#11,#11,#11,#11,#11,#11,#18,#61,#11, #11,#11,#11,#11,#11,#11,#11,#18,#86,#11, #11,#11,#11,#11,#11,#11,#11,#18,#88,#11, #11,#11,#11,#11,#11,#11,#11,#18,#88,#81
db #11,#11,#11,#11,#11,#11,#11,#68,#88,#61, #11,#11,#11,#11,#11,#11,#11,#18,#88,#61, #11,#11,#11,#11,#11,#11,#11,#68,#88,#61, #11,#11,#11,#11,#11,#11,#11,#68,#88,#11, #11,#11,#11,#11,#11,#11,#11,#68,#88,#11
db #11,#11,#11,#11,#11,#11,#11,#18,#81,#11, #11,#11,#11,#11,#11,#11,#11,#16,#11,#11, #11,#11,#11,#11,#11,#11,#11,#11,#11,#11, #11,#11,#11,#11,#11,#11,#11,#18,#11,#11, #11,#11,#11,#11,#11,#11,#11,#88,#81,#11
db #11,#11,#11,#11,#11,#11,#11,#88,#86,#11, #11,#11,#11,#11,#11,#11,#16,#88,#86,#11, #11,#11,#11,#11,#11,#11,#11,#88,#86,#11, #11,#11,#11,#11,#11,#11,#16,#88,#86,#11, #11,#11,#11,#11,#11,#11,#16,#88,#86,#11
db #11,#11,#11,#11,#11,#11,#16,#88,#81,#11, #11,#11,#11,#11,#11,#11,#16,#88,#11,#11, #11,#11,#11,#11,#11,#11,#16,#81,#11,#11, #11,#11,#11,#11,#11,#11,#16,#11,#11,#11, #11,#11,#11,#11,#11,#11,#11,#11,#11,#11
;2
db #11,#11,#68,#88,#88,#88,#88,#88,#88,#61, #11,#11,#16,#88,#88,#88,#88,#88,#86,#61, #11,#11,#11,#88,#88,#88,#88,#88,#16,#86, #11,#11,#11,#18,#88,#88,#88,#86,#68,#81, #11,#11,#11,#11,#11,#11,#11,#16,#88,#81
db #11,#11,#11,#11,#11,#11,#11,#18,#88,#81, #11,#11,#11,#11,#11,#11,#11,#18,#88,#81, #11,#11,#11,#11,#11,#11,#11,#18,#88,#61, #11,#11,#11,#11,#11,#11,#11,#18,#88,#61, #11,#11,#11,#11,#11,#11,#11,#18,#88,#61
db #11,#11,#11,#88,#88,#88,#88,#81,#88,#11, #11,#11,#18,#88,#88,#88,#88,#88,#16,#11, #11,#11,#68,#88,#88,#88,#88,#86,#11,#11, #11,#18,#16,#88,#88,#88,#88,#61,#11,#11, #11,#88,#81,#11,#11,#11,#11,#11,#11,#11
db #11,#88,#86,#11,#11,#11,#11,#11,#11,#11, #11,#88,#86,#11,#11,#11,#11,#11,#11,#11, #16,#88,#86,#11,#11,#11,#11,#11,#11,#11, #16,#88,#86,#11,#11,#11,#11,#11,#11,#11, #16,#88,#86,#11,#11,#11,#11,#11,#11,#11
db #16,#88,#81,#11,#11,#11,#11,#11,#11,#11, #16,#88,#16,#88,#88,#88,#86,#11,#11,#11, #16,#81,#68,#88,#88,#88,#88,#61,#11,#11, #16,#16,#88,#88,#88,#88,#88,#86,#11,#11, #11,#68,#88,#88,#88,#88,#88,#88,#11,#11
;3
db #11,#11,#68,#88,#88,#88,#88,#88,#88,#61, #11,#11,#16,#88,#88,#88,#88,#88,#86,#61, #11,#11,#11,#88,#88,#88,#88,#88,#16,#86, #11,#11,#11,#18,#88,#88,#88,#81,#68,#81, #11,#11,#11,#11,#11,#11,#11,#16,#88,#81
db #11,#11,#11,#11,#11,#11,#11,#18,#88,#81, #11,#11,#11,#11,#11,#11,#11,#18,#88,#81, #11,#11,#11,#11,#11,#11,#11,#18,#88,#61, #11,#11,#11,#11,#11,#11,#11,#18,#88,#61, #11,#11,#11,#11,#11,#11,#11,#18,#88,#61
db #11,#11,#11,#88,#88,#88,#88,#81,#88,#11, #11,#11,#18,#88,#88,#88,#88,#88,#11,#11, #11,#11,#68,#88,#88,#88,#88,#86,#11,#11, #11,#11,#16,#88,#88,#88,#88,#61,#86,#11, #11,#11,#11,#11,#11,#11,#11,#18,#88,#11
db #11,#11,#11,#11,#11,#11,#11,#68,#88,#11, #11,#11,#11,#11,#11,#11,#11,#88,#88,#11, #11,#11,#11,#11,#11,#11,#11,#88,#88,#11, #11,#11,#11,#11,#11,#11,#11,#88,#86,#11, #11,#11,#11,#11,#11,#11,#11,#88,#86,#11
db #11,#11,#11,#11,#11,#11,#11,#88,#86,#11, #11,#11,#16,#88,#88,#88,#86,#18,#86,#11, #11,#11,#68,#88,#88,#88,#88,#61,#86,#11, #11,#16,#88,#88,#88,#88,#88,#86,#66,#11, #11,#68,#88,#88,#88,#88,#88,#88,#11,#11
;4
db #11,#16,#11,#11,#11,#11,#11,#11,#11,#66, #11,#18,#61,#11,#11,#11,#11,#11,#16,#81, #11,#18,#86,#11,#11,#11,#11,#11,#18,#81, #11,#18,#88,#11,#11,#11,#11,#16,#88,#81, #11,#18,#88,#61,#11,#11,#11,#16,#88,#81
db #11,#68,#88,#61,#11,#11,#11,#18,#88,#81, #11,#18,#88,#61,#11,#11,#11,#18,#88,#81, #11,#68,#88,#61,#11,#11,#11,#18,#88,#61, #11,#68,#88,#61,#11,#11,#11,#18,#88,#61, #11,#68,#88,#11,#11,#11,#11,#18,#88,#61
db #11,#18,#81,#88,#88,#88,#88,#81,#88,#11, #11,#16,#18,#88,#88,#88,#88,#88,#11,#11, #11,#11,#68,#88,#88,#88,#88,#86,#11,#11, #11,#11,#16,#88,#88,#88,#88,#61,#86,#11, #11,#11,#11,#11,#11,#11,#11,#16,#88,#11
db #11,#11,#11,#11,#11,#11,#11,#68,#88,#11, #11,#11,#11,#11,#11,#11,#11,#88,#88,#11, #11,#11,#11,#11,#11,#11,#11,#88,#88,#11, #11,#11,#11,#11,#11,#11,#11,#88,#86,#11, #11,#11,#11,#11,#11,#11,#11,#88,#88,#11
db #11,#11,#11,#11,#11,#11,#11,#88,#86,#11, #11,#11,#11,#11,#11,#11,#11,#68,#86,#11, #11,#11,#11,#11,#11,#11,#11,#16,#86,#11, #11,#11,#11,#11,#11,#11,#11,#11,#86,#11, #11,#11,#11,#11,#11,#11,#11,#11,#16,#11
;5
db #11,#11,#68,#88,#88,#88,#88,#88,#88,#61, #11,#18,#16,#88,#88,#88,#88,#88,#81,#11, #11,#18,#81,#88,#88,#88,#88,#88,#11,#11, #11,#18,#86,#18,#88,#88,#88,#81,#11,#11, #11,#18,#88,#61,#11,#11,#11,#11,#11,#11
db #11,#18,#88,#61,#11,#11,#11,#11,#11,#11, #11,#68,#88,#61,#11,#11,#11,#11,#11,#11, #11,#68,#88,#61,#11,#11,#11,#11,#11,#11, #11,#68,#88,#61,#11,#11,#11,#11,#11,#11, #11,#68,#88,#11,#11,#11,#11,#11,#11,#11
db #11,#18,#66,#88,#88,#88,#88,#81,#11,#11, #11,#16,#18,#88,#88,#88,#88,#88,#11,#11, #11,#11,#68,#88,#88,#88,#88,#86,#11,#11, #11,#11,#16,#88,#88,#88,#88,#61,#66,#11, #11,#11,#11,#11,#11,#11,#11,#18,#88,#11
db #11,#11,#11,#11,#11,#11,#11,#68,#88,#11, #11,#11,#11,#11,#11,#11,#11,#88,#88,#11, #11,#11,#11,#11,#11,#11,#11,#88,#88,#11, #11,#11,#11,#11,#11,#11,#11,#88,#86,#11, #11,#11,#11,#11,#11,#11,#11,#88,#86,#11
db #11,#11,#11,#11,#11,#11,#11,#88,#86,#11, #11,#11,#16,#88,#88,#88,#86,#18,#86,#11, #11,#11,#68,#88,#88,#88,#88,#61,#86,#11, #11,#16,#88,#88,#88,#88,#88,#86,#66,#11, #11,#68,#88,#88,#88,#88,#88,#88,#11,#11
;6
db #11,#11,#68,#88,#88,#88,#88,#88,#88,#61, #11,#18,#16,#88,#88,#88,#88,#88,#81,#11, #11,#18,#81,#88,#88,#88,#88,#88,#11,#11, #11,#18,#86,#18,#88,#88,#88,#81,#11,#11, #11,#18,#88,#61,#11,#11,#11,#11,#11,#11
db #11,#18,#88,#61,#11,#11,#11,#11,#11,#11, #11,#68,#88,#61,#11,#11,#11,#11,#11,#11, #11,#68,#88,#61,#11,#11,#11,#11,#11,#11, #11,#68,#88,#61,#11,#11,#11,#11,#11,#11, #11,#68,#88,#11,#11,#11,#11,#11,#11,#11
db #11,#18,#66,#88,#88,#88,#88,#81,#11,#11, #11,#16,#18,#88,#88,#88,#88,#88,#11,#11, #11,#11,#68,#88,#88,#88,#88,#86,#11,#11, #11,#18,#16,#88,#88,#88,#88,#61,#66,#11, #11,#88,#81,#11,#11,#11,#11,#18,#88,#11
db #11,#88,#86,#11,#11,#11,#11,#68,#88,#11, #11,#88,#86,#11,#11,#11,#11,#88,#88,#11, #16,#88,#86,#11,#11,#11,#11,#88,#88,#11, #16,#88,#86,#11,#11,#11,#11,#88,#86,#11, #16,#88,#86,#11,#11,#11,#11,#88,#86,#11
db #16,#88,#81,#11,#11,#11,#11,#88,#86,#11, #16,#88,#16,#88,#88,#88,#86,#18,#86,#11, #16,#81,#68,#88,#88,#88,#88,#61,#86,#11, #16,#16,#88,#88,#88,#88,#88,#86,#66,#11, #11,#68,#88,#88,#88,#88,#88,#88,#11,#11
;7
db #11,#11,#68,#88,#88,#88,#88,#88,#88,#61, #11,#11,#16,#88,#88,#88,#88,#88,#86,#61, #11,#11,#11,#88,#88,#88,#88,#88,#16,#86, #11,#11,#11,#18,#88,#88,#88,#81,#68,#81, #11,#11,#11,#11,#11,#11,#11,#16,#88,#81
db #11,#11,#11,#11,#11,#11,#11,#18,#88,#81, #11,#11,#11,#11,#11,#11,#11,#18,#88,#81, #11,#11,#11,#11,#11,#11,#11,#18,#88,#61, #11,#11,#11,#11,#11,#11,#11,#18,#88,#61, #11,#11,#11,#11,#11,#11,#11,#18,#88,#61
db #11,#11,#11,#11,#11,#11,#11,#11,#88,#11, #11,#11,#11,#11,#11,#11,#11,#11,#11,#11, #11,#11,#11,#11,#11,#11,#11,#11,#11,#11, #11,#11,#11,#11,#11,#11,#11,#11,#66,#11, #11,#11,#11,#11,#11,#11,#11,#18,#88,#11
db #11,#11,#11,#11,#11,#11,#11,#68,#88,#11, #11,#11,#11,#11,#11,#11,#11,#88,#88,#11, #11,#11,#11,#11,#11,#11,#11,#88,#88,#11, #11,#11,#11,#11,#11,#11,#11,#88,#86,#11, #11,#11,#11,#11,#11,#11,#11,#88,#88,#11
db #11,#11,#11,#11,#11,#11,#11,#88,#86,#11, #11,#11,#11,#11,#11,#11,#11,#68,#86,#11, #11,#11,#11,#11,#11,#11,#11,#16,#86,#11, #11,#11,#11,#11,#11,#11,#11,#11,#86,#11, #11,#11,#11,#11,#11,#11,#11,#11,#16,#11
;8
db #11,#11,#68,#88,#88,#88,#88,#88,#88,#61, #11,#18,#16,#88,#88,#88,#88,#88,#86,#61, #11,#18,#81,#88,#88,#88,#88,#88,#16,#86, #11,#18,#86,#18,#88,#88,#88,#81,#68,#81, #11,#18,#88,#61,#11,#11,#11,#16,#88,#81
db #11,#18,#88,#61,#11,#11,#11,#18,#88,#81, #11,#68,#88,#61,#11,#11,#11,#18,#88,#81, #11,#68,#88,#61,#11,#11,#11,#18,#88,#61, #11,#68,#88,#61,#11,#11,#11,#18,#88,#61, #11,#68,#88,#11,#11,#11,#11,#18,#88,#61
db #11,#18,#66,#88,#88,#88,#88,#81,#88,#11, #11,#16,#18,#88,#88,#88,#88,#88,#11,#11, #11,#11,#68,#88,#88,#88,#88,#86,#11,#11, #11,#18,#16,#88,#88,#88,#88,#61,#86,#11, #11,#88,#81,#11,#11,#11,#11,#18,#88,#11
db #11,#88,#86,#11,#11,#11,#11,#68,#88,#11, #11,#88,#86,#11,#11,#11,#11,#88,#88,#11, #16,#88,#86,#11,#11,#11,#11,#88,#88,#11, #16,#88,#86,#11,#11,#11,#11,#88,#86,#11, #16,#88,#86,#11,#11,#11,#11,#88,#86,#11
db #16,#88,#81,#11,#11,#11,#11,#88,#86,#11, #16,#88,#16,#88,#88,#88,#86,#18,#86,#11, #16,#81,#68,#88,#88,#88,#88,#61,#86,#11, #16,#16,#88,#88,#88,#88,#88,#86,#66,#11, #11,#68,#88,#88,#88,#88,#88,#88,#11,#11
;9
db #11,#11,#68,#88,#88,#88,#88,#88,#88,#61, #11,#16,#16,#88,#88,#88,#88,#88,#86,#61, #11,#18,#81,#88,#88,#88,#88,#88,#16,#86, #11,#18,#86,#18,#88,#88,#88,#81,#68,#81, #11,#18,#88,#61,#11,#11,#11,#16,#88,#81
db #11,#18,#88,#61,#11,#11,#11,#18,#88,#81, #11,#68,#88,#61,#11,#11,#11,#18,#88,#81, #11,#68,#88,#61,#11,#11,#11,#18,#88,#61, #11,#68,#88,#61,#11,#11,#11,#18,#88,#61, #11,#68,#88,#11,#11,#11,#11,#18,#88,#61
db #11,#18,#66,#88,#88,#88,#88,#81,#88,#11, #11,#16,#18,#88,#88,#88,#88,#88,#11,#11, #11,#11,#68,#88,#88,#88,#88,#86,#11,#11, #11,#11,#16,#88,#88,#88,#88,#61,#86,#11, #11,#11,#11,#11,#11,#11,#11,#18,#88,#11
db #11,#11,#11,#11,#11,#11,#11,#68,#88,#11, #11,#11,#11,#11,#11,#11,#11,#88,#88,#11, #11,#11,#11,#11,#11,#11,#11,#88,#88,#11, #11,#11,#11,#11,#11,#11,#11,#88,#86,#11, #11,#11,#11,#11,#11,#11,#11,#88,#86,#11
db #11,#11,#11,#11,#11,#11,#11,#88,#86,#11, #11,#11,#16,#88,#88,#88,#86,#18,#86,#11, #11,#11,#68,#88,#88,#88,#88,#61,#86,#11, #11,#16,#88,#88,#88,#88,#88,#86,#66,#11, #11,#68,#88,#88,#88,#88,#88,#88,#11,#11

digsgnbmp db 6,10,4:dw digsgnbmp0:dw $+4,6*8:db 5
digsgnbmp0 ;+
db #11,#11,#11,#11,#11,#11
db #11,#11,#11,#11,#11,#11
db #11,#11,#11,#11,#11,#11
db #11,#11,#11,#11,#11,#11
digsgnbmp1 ;-
db #11,#88,#88,#88,#81,#11
db #18,#88,#88,#88,#88,#11
db #68,#88,#88,#88,#86,#11
db #16,#88,#88,#88,#61,#11


digdgrbmp db 4,7,8:dw $+7:dw $+4,4*8:db 5
db #18,#88,#86,#11
db #18,#88,#88,#61
db #18,#86,#88,#61
db #18,#81,#88,#61
db #68,#81,#88,#11
db #68,#86,#88,#11
db #68,#88,#88,#11
db #16,#88,#88,#11



prgtxtok    db "OK",0
prgtxtcnc   db "Cancel",0

;widget
dsploctxt   db "Koeln, DE",0
dspraitxt   db "Rain XXX%",0
dsphumtxt   db "Humid. XXX%",0
dspwndtxt   db "???? ????kmh",0
dspwndtxt0  db "kmh",0

;forecast
forcsttit   db "Weather forecast",0

dspwd1txt   db "Monday",0
dspdt1txt   db "15.08.",0
dspmn1txt   db "-10C min",0
dspmx1txt   db "30C max",0
dsprn1txt   db "Rain 100%",0

dspwd2txt   db "Tuesday",0
dspdt2txt   db "15.08.",0
dspmn2txt   db "-10C min",0
dspmx2txt   db "30C max",0
dsprn2txt   db "Rain 100%",0

dspwd3txt   db "Wednesday",0
dspdt3txt   db "15.08.",0
dspmn3txt   db "-10C min",0
dspmx3txt   db "30C max",0
dsprn3txt   db "Rain 100%",0

dspwd4txt   db "Thursday",0
dspdt4txt   db "15.08.",0
dspmn4txt   db "-10C min",0
dspmx4txt   db "30C max",0
dsprn4txt   db "Rain 100%",0

dspwd5txt   db "Friday",0
dspdt5txt   db "15.08.",0
dspmn5txt   db "-10C min",0
dspmx5txt   db "30C max",0
dsprn5txt   db "Rain 100%",0

dspwd6txt   db "Saturday",0
dspdt6txt   db "15.08.",0
dspmn6txt   db "-10C min",0
dspmx6txt   db "30C max",0
dsprn6txt   db "Rain 100%",0


;==============================================================================
;### TRANSFER AREA ############################################################
;==============================================================================

App_BegTrns
;### PRGPRZS -> stack for application process
        ds 128
prgstk  ds 6*2
        dw prgprz
App_PrcID db 0

;### App_MsgBuf -> message buffer
App_MsgBuf ds 14

;### WIDGET CONTROL COLLECTION ################################################

wdgobjsup   dw wdggrpwin0,1000,1000,0,0,0

wdggrpwin0  db 8,0:dw wdgdatwin0,0,0,00*256+00,0,0,00
wdgdatwin0
dw 00,255*256+ 0, 128+1,      0, 0,1000,1000,0
dw 00,255*256+ 2,256*255+128, 1, 1,  97,  42,0      ;frame
dw 00,255*256+10,wthsymhed,   5, 6,  32,  32,0      ;weather symbol
dw 00,255*256+10,digsgnbmp,  38,15,  10,   4,0      ;sign
dw 00,255*256+10,digfnthd0,  48, 5,  20,  25,0      ;degree
dw 00,255*256+10,digfnthd1,  68, 5,  20,  25,0
dw 00,255*256+10,digdgrbmp,  89, 5,   7,   8,0      ;°
dw 00,255*256+ 1,dsplocctl,  39,32,  56,   8,0      ;location

wdggrpwin1  db 11,0:dw wdgdatwin1,0,0,00*256+00,0,0,00
wdgdatwin1
dw 00,255*256+ 0, 128+1,      0, 0,1000,1000,0
dw 00,255*256+ 2,256*255+128, 1, 1, 149,  42,0      ;frame
dw 00,255*256+10,wthsymhed,   5, 6,  32,  32,0      ;weather symbol
dw 00,255*256+10,digsgnbmp,  38,15,  10,   4,0      ;sign
dw 00,255*256+10,digfnthd0,  48, 5,  20,  25,0      ;degree
dw 00,255*256+10,digfnthd1,  68, 5,  20,  25,0
dw 00,255*256+10,digdgrbmp,  89, 5,   7,   8,0      ;°
dw 00,255*256+ 1,dsplocctl,  39,32, 107,   8,0      ;location
dw 00,255*256+ 1,dspraictl, 100, 4,  48,   8,0      ;rain in %
dw 00,255*256+ 1,dsphumctl, 100,13,  48,   8,0      ;humidity
dw 00,255*256+ 1,dspwndctl,  90,22,  58,   8,0      ;wind

dsplocctl   dw dsploctxt,16*8+1+512+32768+16384
dspraictl   dw dspraitxt,16*6+1+256+32768+16384
dsphumctl   dw dsphumtxt,16*6+1+256+32768+16384
dspwndctl   dw dspwndtxt,16*6+1+256+32768+16384

;### FORECAST #################################################################

forcstwin   dw #1501,0,059,035,270,80,0,0,270,80,270,80,270,80,prgicnsml,forcsttit,0,0,forcstgrp,0,0:ds 136+14
forcstgrp   db 38,0:dw forcstdat,0,0,256*13+12,0,0,00

forcstdat
dw 00,255*256+ 0, 128+1,      0, 0,1000,1000,0
dw 00,255*256+ 2,256*255+128, 1, 1,  268, 78,0      ;frame

dw 00,255*256+ 1,dspwd1ctl,   4, 2,  44,   8,0      ;1 weekday
dw 00,255*256+ 1,dspdt1ctl,   4,10,  44,   8,0      ;1 date
dw 00,255*256+10,wthsm1hed,   8,20,  32,  32,0      ;1 weather symbol
dw 00,255*256+ 1,dsprn1ctl,   4,54,  44,   8,0      ;1 rain
dw 00,255*256+ 1,dspmx1ctl,   4,62,  44,   8,0      ;1 max
dw 00,255*256+ 1,dspmn1ctl,   4,70,  44,   8,0      ;1 min

dw 00,255*256+ 1,dspwd2ctl,  48, 2,  44,   8,0      ;2 weekday
dw 00,255*256+ 1,dspdt2ctl,  48,10,  44,   8,0      ;2 date
dw 00,255*256+10,wthsm2hed,  52,20,  32,  32,0      ;2 weather symbol
dw 00,255*256+ 1,dsprn2ctl,  48,54,  44,   8,0      ;2 rain
dw 00,255*256+ 1,dspmx2ctl,  48,62,  44,   8,0      ;2 max
dw 00,255*256+ 1,dspmn2ctl,  48,70,  44,   8,0      ;2 min

dw 00,255*256+ 1,dspwd3ctl,  92, 2,  44,   8,0      ;3 weekday
dw 00,255*256+ 1,dspdt3ctl,  92,10,  44,   8,0      ;3 date
dw 00,255*256+10,wthsm3hed,  96,20,  32,  32,0      ;3 weather symbol
dw 00,255*256+ 1,dsprn3ctl,  92,54,  44,   8,0      ;3 rain
dw 00,255*256+ 1,dspmx3ctl,  92,62,  44,   8,0      ;3 max
dw 00,255*256+ 1,dspmn3ctl,  92,70,  44,   8,0      ;3 min

dw 00,255*256+ 1,dspwd4ctl, 136, 2,  44,   8,0      ;4 weekday
dw 00,255*256+ 1,dspdt4ctl, 136,10,  44,   8,0      ;4 date
dw 00,255*256+10,wthsm4hed, 140,20,  32,  32,0      ;4 weather symbol
dw 00,255*256+ 1,dsprn4ctl, 136,54,  44,   8,0      ;4 rain
dw 00,255*256+ 1,dspmx4ctl, 136,62,  44,   8,0      ;4 max
dw 00,255*256+ 1,dspmn4ctl, 136,70,  44,   8,0      ;4 min

dw 00,255*256+ 1,dspwd5ctl, 180, 2,  44,   8,0      ;5 weekday
dw 00,255*256+ 1,dspdt5ctl, 180,10,  44,   8,0      ;5 date
dw 00,255*256+10,wthsm5hed, 184,20,  32,  32,0      ;5 weather symbol
dw 00,255*256+ 1,dsprn5ctl, 180,54,  44,   8,0      ;5 rain
dw 00,255*256+ 1,dspmx5ctl, 180,62,  44,   8,0      ;5 max
dw 00,255*256+ 1,dspmn5ctl, 180,70,  44,   8,0      ;5 min

dw 00,255*256+ 1,dspwd6ctl, 224, 2,  44,   8,0      ;6 weekday
dw 00,255*256+ 1,dspdt6ctl, 224,10,  44,   8,0      ;6 date
dw 00,255*256+10,wthsm6hed, 228,20,  32,  32,0      ;6 weather symbol
dw 00,255*256+ 1,dsprn6ctl, 224,54,  44,   8,0      ;6 rain
dw 00,255*256+ 1,dspmx6ctl, 224,62,  44,   8,0      ;6 max
dw 00,255*256+ 1,dspmn6ctl, 224,70,  44,   8,0      ;6 min

dspwd1ctl   dw dspwd1txt,16*8+1+512+32768+16384
dspdt1ctl   dw dspdt1txt,16*6+1+512+32768+16384
dspmn1ctl   dw dspmn1txt,16*8+1+512+32768+16384
dspmx1ctl   dw dspmx1txt,16*8+1+512+32768+16384
dsprn1ctl   dw dsprn1txt,16*6+1+512+32768+16384

dspwd2ctl   dw dspwd2txt,16*8+1+512+32768+16384
dspdt2ctl   dw dspdt2txt,16*6+1+512+32768+16384
dspmn2ctl   dw dspmn2txt,16*8+1+512+32768+16384
dspmx2ctl   dw dspmx2txt,16*8+1+512+32768+16384
dsprn2ctl   dw dsprn2txt,16*6+1+512+32768+16384

dspwd3ctl   dw dspwd3txt,16*8+1+512+32768+16384
dspdt3ctl   dw dspdt3txt,16*6+1+512+32768+16384
dspmn3ctl   dw dspmn3txt,16*8+1+512+32768+16384
dspmx3ctl   dw dspmx3txt,16*8+1+512+32768+16384
dsprn3ctl   dw dsprn3txt,16*6+1+512+32768+16384

dspwd4ctl   dw dspwd4txt,16*8+1+512+32768+16384
dspdt4ctl   dw dspdt4txt,16*6+1+512+32768+16384
dspmn4ctl   dw dspmn4txt,16*8+1+512+32768+16384
dspmx4ctl   dw dspmx4txt,16*8+1+512+32768+16384
dsprn4ctl   dw dsprn4txt,16*6+1+512+32768+16384

dspwd5ctl   dw dspwd5txt,16*8+1+512+32768+16384
dspdt5ctl   dw dspdt5txt,16*6+1+512+32768+16384
dspmn5ctl   dw dspmn5txt,16*8+1+512+32768+16384
dspmx5ctl   dw dspmx5txt,16*8+1+512+32768+16384
dsprn5ctl   dw dsprn5txt,16*6+1+512+32768+16384

dspwd6ctl   dw dspwd6txt,16*8+1+512+32768+16384
dspdt6ctl   dw dspdt6txt,16*6+1+512+32768+16384
dspmn6ctl   dw dspmn6txt,16*8+1+512+32768+16384
dspmx6ctl   dw dspmx6txt,16*8+1+512+32768+16384
dsprn6ctl   dw dsprn6txt,16*6+1+512+32768+16384
