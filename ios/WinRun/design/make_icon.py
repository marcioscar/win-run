import math, sys
from PIL import Image, ImageDraw, ImageFilter, ImageChops

S = 4096            # desenha grande e reduz (antialias)
OUT = 1024
k = S / 1024        # escala: coordenadas pensadas em 1024

def P(x, y): return (x * k, y * k)

# ---------- fundo: gradiente radial vinho ----------
bg = Image.new("RGB", (S, S))
cx, cy = 0.42 * S, 0.38 * S
inner, outer = (128, 22, 52), (34, 5, 14)
small = Image.new("RGB", (256, 256))
px = small.load()
for y in range(256):
    for x in range(256):
        d = math.hypot(x / 255 * S - cx, y / 255 * S - cy) / (0.95 * S)
        t = min(1, d) ** 1.2
        px[x, y] = tuple(int(inner[i] + (outer[i] - inner[i]) * t) for i in range(3))
bg = small.resize((S, S), Image.BICUBIC)

# ---------- camada da taça (desenhada reta e depois inclinada) ----------
layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
gx = 560            # centro horizontal da taça
rim_y, bowl_h, bowl_w = 250, 360, 400
n = 2.6
bowl = []
for i in range(0, 181):
    t = math.radians(i)
    c, s = math.cos(t), math.sin(t)
    x = gx + (bowl_w / 2) * math.copysign(abs(c) ** (2 / n), c)
    y = rim_y + bowl_h * (abs(s) ** (2 / n))
    bowl.append(P(x, y))
bowl_poly = bowl  # vai da borda direita, desce e sobe até a esquerda

cream = (246, 234, 208, 255)
gold = (233, 185, 73, 255)

# vidro (leve)
glass = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(glass).polygon(bowl_poly, fill=(255, 255, 255, 34))
layer = Image.alpha_composite(layer, glass)

# vinho: dentro da taça, abaixo de uma linha inclinada (balança para trás)
bowl_mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(bowl_mask).polygon(bowl_poly, fill=255)
wave = Image.new("L", (S, S), 0)
wl, wr = 395, 470    # altura da superfície: mais alta à esquerda (para trás)
pts = [P(gx - 260, wl - 20)]
for i in range(0, 101):
    x = gx - 220 + 440 * i / 100
    y = wl + (wr - wl) * i / 100 + 10 * math.sin(i / 100 * math.pi * 2)
    pts.append(P(x, y))
pts += [P(gx + 260, 800), P(gx - 260, 800)]
ImageDraw.Draw(wave).polygon(pts, fill=255)
wine_mask = ImageChops.multiply(bowl_mask, wave)
wine = Image.new("RGBA", (S, S), (176, 16, 56, 255))
# brilho no vinho
shine = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(shine).ellipse([*P(gx - 170, 440), *P(gx - 20, 600)], fill=(230, 70, 110, 70))
shine = shine.filter(ImageFilter.GaussianBlur(110 * k / 4))
wine = Image.alpha_composite(wine, shine)
wine.putalpha(wine_mask)
layer = Image.alpha_composite(layer, wine)

# contorno da taça
d = ImageDraw.Draw(layer)
w = int(22 * k)
# traço liso: carimba círculos ao longo do contorno
r = w / 2
for (a, b) in zip(bowl_poly, bowl_poly[1:]):
    steps = max(1, int(math.hypot(b[0] - a[0], b[1] - a[1]) / (r / 3)))
    for j in range(steps + 1):
        x = a[0] + (b[0] - a[0]) * j / steps
        y = a[1] + (b[1] - a[1]) * j / steps
        d.ellipse([x - r, y - r, x + r, y + r], fill=cream)
# haste e base
stem_top = rim_y + bowl_h - 4
d.rounded_rectangle([*P(gx - 13, stem_top), *P(gx + 13, 800)], radius=int(10 * k), fill=cream)
d.rounded_rectangle([*P(gx - 125, 786), *P(gx + 125, 816)], radius=int(15 * k), fill=cream)
# reflexo no vidro
d.arc([*P(gx - 165, rim_y - 60), *P(gx + 5, rim_y + 270)], start=150, end=200, fill=(255, 255, 255, 150), width=int(16 * k))

# inclina a taça para frente (direção da corrida)
layer = layer.rotate(-13, resample=Image.BICUBIC, center=P(gx, 800))

# ---------- linhas de velocidade ----------
speed = Image.new("RGBA", (S, S), (0, 0, 0, 0))
sd = ImageDraw.Draw(speed)
for (x1, x2, y, th, a) in [(150, 400, 360, 30, 255), (90, 380, 470, 30, 255), (190, 395, 580, 30, 210)]:
    sd.rounded_rectangle([*P(x1, y - th / 2), *P(x2, y + th / 2)], radius=int(th / 2 * k), fill=gold[:3] + (a,))

# sombra suave da taça
shadow = layer.split()[3].filter(ImageFilter.GaussianBlur(40 * k / 4))
sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
sh.putalpha(shadow.point(lambda v: int(v * 0.45)))
sh = ImageChops.offset(sh, int(10 * k), int(22 * k))

img = bg.convert("RGBA")
for l in (speed, sh, layer):
    img = Image.alpha_composite(img, l)
img = img.convert("RGB").resize((OUT, OUT), Image.LANCZOS)
img.save(sys.argv[1])
print("ok", sys.argv[1])
