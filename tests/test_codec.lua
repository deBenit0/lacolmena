local H = ...
local client = H.NewClient("Codec")
local Codec = client.ns.Codec

-- Enteros: ida y vuelta y concatenación sin separadores.
local numbers = { 0, 1, 31, 32, 33, 1023, 1024, 65535, 4294967295, 2 ^ 40, 2 ^ 52 - 1 }
for i = 1, 300 do numbers[#numbers + 1] = math.random(0, 10 ^ 9) end
local joined = {}
for _, n in ipairs(numbers) do
  local s = Codec.EncodeUInt(n)
  local back, nextPos = Codec.DecodeUInt(s, 1)
  H.eq(back, n, "EncodeUInt ida y vuelta")
  H.eq(nextPos, #s + 1, "EncodeUInt consume todo")
  joined[#joined + 1] = s
end
local all, pos = table.concat(joined), 1
for _, n in ipairs(numbers) do
  local v
  v, pos = Codec.DecodeUInt(all, pos)
  H.eq(v, n, "números encadenados")
end
H.ok(Codec.DecodeUInt("ABC", 1) == nil, "número sin cifra final no es válido")
H.ok(Codec.DecodeUInt("%", 1) == nil, "carácter extraño no es válido")

-- Listas de identificadores.
H.eq(Codec.DecodeIDs(Codec.EncodeIDs({ 12360, 3577, 6037, 3577, 7080 })), { 3577, 6037, 7080, 12360 }, "lista de IDs ordenada y sin repetidos")
H.eq(Codec.DecodeIDs(""), {}, "lista vacía")
H.eq(Codec.DecodeIDs(nil), {}, "lista nil")
H.ok(Codec.DecodeIDs("AB") == nil, "lista corrupta")
local big = {}
for i = 1, 400 do big[i] = 2000 + i * 37 end
local encoded = Codec.EncodeIDs(big)
H.eq(Codec.DecodeIDs(encoded), big, "lista grande")
H.ok(#encoded <= 400 * 2 + 3, "lista grande compacta (" .. #encoded .. " bytes)")

-- Tablas.
local samples = {
  {},
  { 1, 2, 3 },
  { a = 1, b = -5, c = 0.25, d = "texto", e = true, f = false },
  { nested = { deeper = { "x", { y = "z" } } }, [10] = "diez", [-3] = "menos tres" },
  { raro = "{}'+-.!~;\"|", utf8 = "Fundillö Ñandú áéíóú", vacio = "" },
  { n = 1767225600, big = 2 ^ 50, neg = -2 ^ 40, frac = -1234.5678 },
}
for _, t in ipairs(samples) do
  local s = Codec.Serialize(t)
  H.eq(Codec.Deserialize(s), t, "serialización ida y vuelta")
  H.ok(not s:find("\0", 1, true), "sin bytes nulos")
end
H.eq(Codec.Deserialize(Codec.Serialize(false)), false, "falso suelto")
H.eq(Codec.Deserialize(Codec.Serialize("hola")), "hola", "texto suelto")

-- Determinismo: el orden de inserción no cambia el resultado.
local a, b = {}, {}
for i = 1, 50 do a["k" .. i] = i; a[i] = "v" .. i end
for i = 50, 1, -1 do b[i] = "v" .. i; b["k" .. i] = i end
H.eq(Codec.Serialize(a), Codec.Serialize(b), "serialización determinista")
H.eq(Codec.Hash(Codec.Serialize(a)), Codec.Hash(Codec.Serialize(b)), "huella determinista")
H.ok(Codec.Hash("a") ~= Codec.Hash("b"), "huellas distintas")

-- Textos corruptos: nunca lanzan errores.
local broken = { "{", "}", "+", "'5ab", "{+1}", "{'1a", ".1.2.3;", ".nan;", ".inf;", "{.nan;+1}", "+1+2", "zz", "" }
for _, s in ipairs(broken) do
  H.ok(Codec.Deserialize(s) == nil, "texto corrupto rechazado: " .. s)
end
local chars = "{}+-.'!~;abcXYZ0129#$"
for i = 1, 3000 do
  local len = math.random(1, 30)
  local buf = {}
  for j = 1, len do
    local k = math.random(1, #chars)
    buf[j] = chars:sub(k, k)
  end
  local ok = pcall(Codec.Deserialize, table.concat(buf))
  if not ok then H.ok(false, "Deserialize lanzó un error con " .. table.concat(buf)) break end
end
H.ok(true, "textos aleatorios sin errores")
