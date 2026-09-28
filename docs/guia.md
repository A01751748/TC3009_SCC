# Práctica — Un producto con un modelo de lenguaje propio

Hasta ahora tu modelo lo entrenaste tú. Este viene hecho, pesa 1 GB, y corre **en tu
instancia**: nada sale a internet, no hay API key, no hay factura por token.

Lo que cambia es todo lo demás. Un modelo de lenguaje no devuelve un número: devuelve texto,
tarda, y a veces se equivoca con total seguridad. Construir un producto encima de eso es un
problema distinto, y esta práctica va de eso.

```
   Fase 1   un backend en Flask que habla con Ollama          ~60 min
   Fase 2a  un frontend en React que habla con el backend     ~45 min
   Fase 2b  la respuesta aparece escribiéndose, no de golpe   ~30 min
```

---

## Dónde se hace cada cosa

El mismo reparto de siempre, con un invitado nuevo:

```
   Tu computadora  ─push──▶  TU repo  ─clone/pull──▶  Tu instancia (t2.large)
   ────────────────                                   ──────────────────────
   VS Code                                            Flask      :8080
   editas, no ejecutas                                React      :3000
                                                      Ollama     :11434  ← local, no se expone
```

**Ollama vive solo en la instancia.** Tu computadora no lo necesita: solo edita código.

Los puertos 8080 y 3000 ya están abiertos en tu security group desde la parte 1, así que no
hay que tocar la consola de AWS. El **11434 no se abre**, y eso es una decisión, no un olvido:
si estuviera abierto, cualquiera podría preguntarle al modelo directamente saltándose tu API —
sin tu validación, sin tu tope de tokens, sin tu registro.

> Tu backend es la única puerta al modelo. Esa frase vale para Ollama y vale igual para
> OpenAI: el día que uses una API de pago, el backend es lo que impide que tu clave viva en el
> navegador de un desconocido.

---

## El modelo

Lo instaló `setup/bootstrap.sh` cuando aprovisionaste la instancia. Compruébalo con
`ollama list`. Lo que sigue es **por qué ese y no otro**, que es la primera decisión de
producto de esta práctica.

### Por qué ese modelo y no otro

Una t2.large tiene 8 GB de RAM, 2 vCPU y **no tiene GPU**. Eso descarta casi todo. Probé los
que sí caben, con la misma pregunta en los tres:

| modelo | tamaño | ¿recuerda la conversación? |
|---|---:|---|
| `llama3.2:1b` | 1.3 GB | **1 de 5** — y además inventa |
| `qwen2.5:1.5b` | 1.0 GB | 5 de 5 |
| `llama3.2:3b` | 2.0 GB | 5 de 5, pero el doble de lento |

El fallo del `1b` no es que olvide, es que **rellena**. Le dije «me llamo Victor, mi color
favorito es el verde» y al preguntarle después respondió, en tres intentos seguidos:

```
· Me llamo Luis y mi color favorito es el rojo.
· Tienes 30 años.
· Te llamo Mateo y mi color favorito es el azul.
```

Un modelo que inventa con esa naturalidad es inservible para conversar, y es la primera cosa
que esta práctica te enseña: **el tamaño del modelo es una decisión de producto**, y la mides
probándola, no leyendo la ficha técnica.

### Lo lento que va, medido

En una t2.large real, `llama3.2:3b` da **5.8 tokens por segundo**. Eso significa:

```
   una respuesta de 100 tokens   ~17 segundos
   una respuesta de 400 tokens   ~69 segundos
```

`qwen2.5:1.5b` va aproximadamente al doble. Aun así, **mídelo en la tuya** — es una línea:

```bash
curl -s http://localhost:11434/api/generate \
  -d '{"model":"qwen2.5:1.5b","prompt":"Explica que es una API en tres frases.","stream":false}' \
  | python3 -c "import sys,json;d=json.load(sys.stdin);print(f\"{d['eval_count']/(d['eval_duration']/1e9):.1f} tok/s\")"
```

Ese número manda sobre dos decisiones que vas a tomar en la fase 1, y sobre toda la fase 2b.

---

## Fase 1 — El backend (60 min)

### Antes de escribir nada

Ya tienes tu repositorio y tu instancia aprovisionada — si no,
[00-setup.md](00-setup.md), son quince minutos.

**En la instancia:**

```bash
cd ~/TU-REPO
./run start
./run salud
```

Te va a responder:

```json
{"modelo": "qwen2.5:1.5b", "status": "sin escribir"}
```

Eso es correcto: el esqueleto está vacío. Hay **tres `COMPLETA`** en
[backend/app.py](../backend/app.py), y la aplicación te dice cuál falta conforme avanzas.

### El ciclo, cada vez que escribas algo

```bash
# en tu computadora
git add -A && git commit -m "completa 1" && git push

# en la instancia
git pull && ./run restart && ./run salud
```

### El mapa, antes de escribir

```
   POST /api/chat          ──▶  POST {OLLAMA}/api/chat
   {"messages": [...]}          {"model", "messages", "stream", "options"}
        ▲                                    │
        │                                    ▼
   {"respuesta", "tokens"}  ◀──  {"message": {"content"}, "eval_count"}
```

Tu backend es un **traductor con opiniones**: recibe en tu formato, habla con Ollama en el
suyo, y devuelve en el tuyo. Las opiniones son el mensaje de sistema, el tope de tokens y el
timeout — y son lo que lo convierte en un producto en vez de un proxy.

Y fíjate en lo que **no** hace: guardar la conversación. Recibe la lista completa de mensajes
en cada petición. Quien recuerda es el cliente.

> Un backend sin estado se reinicia, se duplica y se depura sin perder nada. Además, en la
> fase 2 vas a ver exactamente lo que recibe el modelo, porque lo mandas tú.

### `COMPLETA 1` — ¿vive Ollama?

Lo primero no es hablar con el modelo: es saber si está. Reemplaza el `COMPLETA 1` por esto:

```python
    try:
        r = requests.get(f"{OLLAMA}/api/tags", timeout=5)
        r.raise_for_status()
        instalados = [m["name"] for m in r.json().get("models", [])]
    except requests.RequestException as e:
        return jsonify({
            "status": "degradado",
            "modelo": MODELO,
            "detalle": f"Ollama no responde en {OLLAMA}: {str(e)[:100]}",
            "arreglo": "En la instancia:  ollama serve",
        })

    if MODELO not in instalados:
        return jsonify({
            "status": "degradado",
            "modelo": MODELO,
            "detalle": f"'{MODELO}' no esta instalado",
            "instalados": instalados,
            "arreglo": f"En la instancia:  ollama pull {MODELO}",
        })

    return jsonify({"status": "ok", "modelo": MODELO, "max_tokens": MAX_TOKENS})
```

Tres respuestas distintas, y cada una **dice qué hacer**. Un chequeo de salud que solo
responda `ok` o `error` no sirve: cuando algo falla, lo que necesitas es saber cuál de las
tres cosas está mal.

El `timeout=5` es corto a propósito. Esto es un chequeo, no una pregunta al modelo: si Ollama
está caído tiene que decirlo rápido, no colgarse dos minutos.

Guarda, empuja, y en la instancia:

```bash
git pull && ./run restart && ./run salud
```

```json
{"status": "ok", "modelo": "qwen2.5:1.5b", "max_tokens": 180}
```

**Pruébalo roto también**, que es donde se ve si sirve: para Ollama (`pkill ollama`) y vuelve
a pedir salud. Tiene que decirte `ollama serve`. Luego arráncalo otra vez.

### `COMPLETA 2` — la llamada al modelo

```python
    try:
        r = requests.post(
            f"{OLLAMA}/api/chat",
            json={
                "model": MODELO,
                # El mensaje de sistema lo pone el servidor, no el cliente: es
                # parte de como se comporta TU producto, y no algo que quien
                # usa el chat deba poder cambiar desde el navegador.
                "messages": [{"role": "system", "content": SISTEMA}] + mensajes,
                "stream": False,
                "options": {"num_predict": MAX_TOKENS},
            },
            timeout=TIMEOUT,
        )
```

Tres decisiones en ese bloque, y ninguna es de estilo:

**El mensaje de sistema lo pone el servidor.** Va delante de todo y el cliente no puede
tocarlo. Si lo mandara el navegador, cualquiera podría reescribir el comportamiento de tu
producto abriendo las herramientas de desarrollador.

**`num_predict` acota la respuesta.** Sin tope, una pregunta abierta da 400 tokens, y a 6
tokens/segundo eso es **más de un minuto** mirando una pantalla quieta. Lo medí:

```
   sin límite         390 tokens  →  67 s
   num_predict=180    180 tokens  →  31 s
```

No es censura: es que un producto que tarda un minuto en contestar no lo usa nadie. El número
correcto sale de tu medición, no de esta guía.

**`timeout=TIMEOUT`.** Sin él, una petición colgada ocupa un worker para siempre y el
siguiente que pregunte se queda esperando. Con 30 personas contra la misma t2.large, eso pasa.

### `COMPLETA 3` — cuando algo sale mal

```python
    except requests.Timeout:
        return jsonify({
            "error": f"el modelo tardo mas de {TIMEOUT}s",
            "pista": "normal en una t2.large si la pregunta pide mucho texto",
        }), 504
    except requests.RequestException:
        return jsonify({
            "error": f"no pude hablar con Ollama en {OLLAMA}",
            "arreglo": "En la instancia:  ollama serve",
        }), 503

    if r.status_code != 200:
        # Ollama dice cosas utiles cuando falla --por ejemplo que el modelo no
        # existe-- y esconderlas tras un 500 generico no ayuda a nadie.
        return jsonify({
            "error": "Ollama rechazo la peticion",
            "detalle": r.text[:200],
        }), 502

    datos = r.json()
    return jsonify({
        "respuesta": datos.get("message", {}).get("content", ""),
        "modelo": MODELO,
        "tokens": datos.get("eval_count", 0),
    })
```

Tres fallos, tres códigos distintos, y cada uno dice qué hacer:

| | | |
|---|---|---|
| `504` | tardó demasiado | es culpa de la máquina, no tuya |
| `503` | Ollama no contesta | `ollama serve` |
| `502` | Ollama rechazó | se reenvía **su** mensaje, que suele nombrar el problema |

Devolver `tokens` parece de adorno y no lo es: es lo que te deja ver el costo de cada
respuesta. Hoy el costo es tiempo; el día que uses una API de pago, es dinero.

### Pruébalo

**En la instancia:**

```bash
curl -s -X POST http://localhost:8080/api/chat \
  -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"Que es una API REST, en dos frases?"}]}'
```

```json
{
  "respuesta": "Una API REST es una herramienta que permite a un programa conectarse a un servicio web...",
  "modelo": "qwen2.5:1.5b",
  "tokens": 41
}
```

### Lo que hay que ver antes de cerrar la fase

**Que no tiene memoria.** Manda dos peticiones por separado:

```bash
curl -s -X POST http://localhost:8080/api/chat -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"Me llamo Victor."}]}'

curl -s -X POST http://localhost:8080/api/chat -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"Como me llamo?"}]}'
```

No se acuerda, y **está bien**. Ahora manda la conversación entera:

```bash
curl -s -X POST http://localhost:8080/api/chat -H 'Content-Type: application/json' -d '{
  "messages":[
    {"role":"user","content":"Me llamo Victor y doy clase de IA."},
    {"role":"assistant","content":"Hola Victor."},
    {"role":"user","content":"Como me llamo y que doy?"}
  ]}'
```

```
Tu nombre es Victor, y eres un experto en Inteligencia Artificial.
```

**La memoria no está en el modelo ni en tu servidor: está en la lista que mandas.** Eso es
todo lo que hay detrás de que un chat «recuerde», y es exactamente lo que vas a construir en
la fase 2 — porque el frontend va a ser quien guarde esa lista.

**Y que la validación llega antes que el modelo:**

```bash
curl -s -X POST http://localhost:8080/api/chat -H 'Content-Type: application/json' -d '{}'
```

```json
{"error": "se esperaba {\"messages\": [...]} y no llego"}
```

Instantáneo, sin gastar treinta segundos de CPU para acabar en un error de formato. Con 30
personas contra la misma máquina, eso importa.

---

## Fase 2 — El frontend

*(En construcción. Aquí el chat en React: primero la respuesta completa, después
escribiéndose token a token.)*

---

## Si te atoras

**En la instancia:**

```bash
git pull            # ¿de verdad llegó lo que escribiste?
./run status        # ¿vive el backend? ¿vive Ollama?
./run salud         # ¿está mi modelo?
./run modelo        # ¿qué modelos hay instalados?
./run logs api      # el error completo
```

| Síntoma | Qué pasa |
| ------- | -------- |
| `"status": "sin escribir"` | El `COMPLETA 1` sigue vacío |
| `NotImplementedError: COMPLETA 2` en los logs | El `COMPLETA 2` sigue vacío |
| `"arreglo": "ollama serve"` | Ollama no está corriendo |
| `"arreglo": "ollama pull ..."` | El modelo no está descargado |
| Tarda muchísimo | Normal. Baja `OLLAMA_MAX_TOKENS` o usa un modelo más chico |

El modelo, el tope y el timeout salen de variables de entorno, así que probar otro es una
línea y no tocar código:

```bash
OLLAMA_MODEL=llama3.2:3b OLLAMA_MAX_TOKENS=120 ./run restart
```
