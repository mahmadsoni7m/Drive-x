# Иловаи мундариҷаи нав (мошин, либос, персонаж, пойга)

Ҳама мундариҷа дар `content/` ҳамчун файлҳои JSON нигоҳ дошта мешавад. Барои иловаи чизи нав кодро тағйир додан лозим нест.

1. Файли JSON-ро ба папкаи мувофиқ гузоред: `content/cars/`, `content/outfits/`, `content/characters/`, `content/races/`.
2. `id`-и онро ба `content/index.json` дар рӯйхати мувофиқ илова кунед.
3. CI худаш `Content.validate()`-ро иҷро мекунад ва хатогиҳоро нишон медиҳад.

## Мошини нав (`content/cars/<id>.json`)
`id, name, price, color(hex), top (м/с), accel, handling, nitro, len, wid, hei, cabin, spoiler, stripe`.
Модели Blender (ихтиёрӣ): `assets/models/<id>.glb` бо гиреҳҳои `Wheel_FL/FR/RL/RR` (`tools/blender/generate_cars.py`).

## Либоси нав (`content/outfits/<id>.json`)
`id, slot (top|bottom|shoes|hat), name, price, color, accent, style, shop`.
Услубҳо: top = tshirt | long | jacket | robe; bottom = pants | shorts | skirt; hat = cap | toqi. `shop:false` — танҳо барои персонажҳои бозӣ.

## Персонажи нав (`content/characters/<id>.json`)
`id, name, role (npc|fighter), skin, hair, hair_style (short|long|none), scale, hp, outfit{top,bottom,shoes,hat}`.

## Пойгаи нав (`content/races/<id>.json`)
`id, name, laps, ai, reward, skill, waypoints[[x,z],...]` — давраи пӯшида; нуқтаҳо бояд дар болои роҳ бошанд (санҷиши худкор дорад).

## Матнҳо
Ҳама матн дар `content/locale/tg.json` (тоҷикӣ). Дар код: `Lang.t("калид")`.
