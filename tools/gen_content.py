"""Generates the starter JSON content. Safe to re-run; to add content just drop another JSON file
into content/<kind>/ and list its id in content/index.json (see docs/ADDING_CONTENT.md)."""
import json, math, os

def w(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)

cars = [
 dict(id="gt_rookie", name="ГТ Навкор", price=0, color="e63946", top=46, accel=15, handling=1.0, nitro=1.0, len=4.3, wid=1.8, hei=0.5, cabin=0.5, spoiler=False, stripe=False),
 dict(id="street_fox", name="Рӯбоҳи кӯча", price=2500, color="ff9f1c", top=52, accel=17, handling=1.05, nitro=1.05, len=4.1, wid=1.8, hei=0.52, cabin=0.52, spoiler=True, stripe=True),
 dict(id="apex_r", name="Апекс-Р", price=7000, color="2ec4b6", top=58, accel=19, handling=1.12, nitro=1.1, len=4.4, wid=1.9, hei=0.46, cabin=0.46, spoiler=True, stripe=False),
 dict(id="viper_s", name="Афъӣ-С", price=16000, color="7b2cbf", top=66, accel=21.5, handling=1.15, nitro=1.2, len=4.5, wid=1.95, hei=0.44, cabin=0.44, spoiler=True, stripe=True),
 dict(id="phantom_x", name="Шабаҳ-Х", price=35000, color="e8ecf4", top=76, accel=24, handling=1.2, nitro=1.35, len=4.6, wid=2.0, hei=0.42, cabin=0.42, spoiler=True, stripe=True),
]
for c in cars: w(f"content/cars/{c['id']}.json", c)

def o(id, slot, name, price, color, style, accent="ffffff", shop=True):
    return dict(id=id, slot=slot, name=name, price=price, color=color, accent=accent, style=style, shop=shop)
outfits = [
 o("top_tshirt_white","top","Футболкаи сафед",0,"f2f2f2","tshirt"),
 o("top_tshirt_red","top","Футболкаи сурх",300,"d62828","tshirt"),
 o("top_hoodie_blue","top","Ҳудии кабуд",700,"2a62c9","long"),
 o("top_jacket_black","top","Куртаи сиёҳ",900,"1b1b22","jacket"),
 o("top_chapan","top","Чопони тоҷикӣ",2500,"1f7a4d","robe","e0b84a"),
 o("bottom_jeans_blue","bottom","Ҷинси кабуд",0,"2d4f86","pants"),
 o("bottom_pants_black","bottom","Шими сиёҳ",400,"1a1a1f","pants"),
 o("bottom_shorts_khaki","bottom","Шими кӯтоҳи хаки",250,"b3a36a","shorts"),
 o("shoes_sneakers_white","shoes","Кроссовкаи сафед",0,"f4f4f4","shoes"),
 o("shoes_sneakers_red","shoes","Кроссовкаи сурх",350,"d62828","shoes"),
 o("shoes_boots_brown","shoes","Ботинкаи қаҳваӣ",500,"5a3b22","shoes"),
 o("hat_cap_black","hat","Кепкаи сиёҳ",200,"1b1b22","cap"),
 o("hat_cap_red","hat","Кепкаи сурх",200,"d62828","cap"),
 o("hat_toqi","hat","Тоқии тоҷикӣ",600,"15151c","toqi","f2f2f2"),
 # NPC / fighter-only items (not sold in the wardrobe)
 o("npc_top_green","top","Куртаи сабз",0,"3d8b4a","long","ffffff",False),
 o("npc_top_yellow","top","Футболкаи зард",0,"e5b92f","tshirt","ffffff",False),
 o("npc_top_gray","top","Куртаи хокистарӣ",0,"6b7280","jacket","ffffff",False),
 o("npc_top_pink","top","Блузаи гулобӣ",0,"d96aa7","long","ffffff",False),
 o("npc_skirt_dark","bottom","Домани торик",0,"3a2a4a","skirt","ffffff",False),
 o("npc_pants_brown","bottom","Шими қаҳваӣ",0,"5a4632","pants","ffffff",False),
 o("fighter_top_black","top","Куртаи ҷангӣ",0,"15151a","jacket","b01010",False),
 o("fighter_top_red","top","Майкаи сурх",0,"a31515","tshirt","ffffff",False),
 o("fighter_pants_camo","bottom","Шими камуфляж",0,"4a5a35","pants","ffffff",False),
 o("fighter_boots_black","shoes","Ботинкаи сиёҳ",0,"101012","shoes","ffffff",False),
]
for x in outfits: w(f"content/outfits/{x['id']}.json", x)

def ch(id, name, role, skin, hair, hs, scale, hp, top, bottom, shoes, hat=""):
    return dict(id=id, name=name, role=role, skin=skin, hair=hair, hair_style=hs, scale=scale, hp=hp,
                outfit=dict(top=top, bottom=bottom, shoes=shoes, hat=hat))
chars = [
 ch("npc_man_a","Мардуми шаҳр А","npc","d9a066","201510","short",1.0,40,"npc_top_green","npc_pants_brown","shoes_sneakers_white"),
 ch("npc_man_b","Мардуми шаҳр Б","npc","a56a3c","15100c","short",1.05,40,"top_tshirt_red","bottom_jeans_blue","shoes_boots_brown","hat_toqi"),
 ch("npc_man_c","Мардуми шаҳр В","npc","f1c8a5","5a3b22","short",0.97,40,"npc_top_gray","bottom_pants_black","shoes_sneakers_red","hat_cap_black"),
 ch("npc_woman_a","Занони шаҳр А","npc","d9a066","15100c","long",0.93,35,"npc_top_pink","npc_skirt_dark","shoes_sneakers_white"),
 ch("npc_woman_b","Занони шаҳр Б","npc","a56a3c","201510","long",0.95,35,"npc_top_yellow","bottom_jeans_blue","shoes_sneakers_red"),
 ch("npc_man_d","Мардуми шаҳр Г","npc","6b4226","0a0806","none",1.02,40,"top_hoodie_blue","bottom_shorts_khaki","shoes_sneakers_white"),
 ch("fighter_a","Ҷанговар А","fighter","d9a066","0a0806","short",1.08,70,"fighter_top_black","fighter_pants_camo","fighter_boots_black"),
 ch("fighter_b","Ҷанговар Б","fighter","a56a3c","0a0806","none",1.12,90,"fighter_top_red","bottom_pants_black","fighter_boots_black","hat_cap_black"),
 ch("fighter_c","Ҷанговар В","fighter","f1c8a5","3a2a1a","short",1.04,60,"fighter_top_black","bottom_pants_black","shoes_boots_brown"),
]
for x in chars: w(f"content/characters/{x['id']}.json", x)

def dirt_loop(cx, cz, base, wob, freq, n, start):
    pts = []
    for i in range(n):
        a = start + 2*math.pi*i/n
        r = base + wob*math.sin(freq*a)
        pts.append([round(cx + r*math.cos(a), 3), round(cz + r*math.sin(a), 3)])
    return pts
ring = [[round(800*math.cos(2*math.pi*((i+6)%48)/48), 3), round(800*math.sin(2*math.pi*((i+6)%48)/48), 3)] for i in range(48)]
city = [[-120,-150],[0,-150],[120,-150],[150,-150],[150,-120],[150,0],[150,120],[150,150],[120,150],[0,150],[-120,150],[-150,150],[-150,120],[-150,0],[-150,-120],[-150,-150]]
south = dirt_loop(0,1000,120,25,3,12,-math.pi/2)
east = dirt_loop(1000,0,110,20,4,12,math.pi)
races = [
 dict(id="ring_highway", name="Шоҳроҳи ҳалқавӣ", laps=2, ai=4, reward=900, skill=0.92, waypoints=ring),
 dict(id="city_loop", name="Давраи шаҳр", laps=3, ai=4, reward=600, skill=0.85, waypoints=city),
 dict(id="mountain_south", name="Роҳи кӯҳии ҷануб", laps=3, ai=4, reward=1200, skill=0.88, waypoints=south),
 dict(id="mountain_east", name="Роҳи кӯҳии шарқ", laps=3, ai=5, reward=1400, skill=0.92, waypoints=east),
]
for r in races: w(f"content/races/{r['id']}.json", r)

w("content/index.json", dict(
    cars=[c["id"] for c in cars], outfits=[x["id"] for x in outfits],
    characters=[x["id"] for x in chars], races=[r["id"] for r in races]))
print("cars", len(cars), "outfits", len(outfits), "characters", len(chars), "races", len(races))
