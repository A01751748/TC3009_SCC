# Antes de empezar

Quince minutos, y se hace **una sola vez** para toda la parte 2.

---

## Cómo se trabaja en esta parte

En la parte 1 cada quien hizo un *fork*. Aquí no. El fork ata tu repositorio al del curso, y
cuando algo se desincroniza —que pasa— arreglarlo es complicado justo cuando menos tiempo
tienes.

Esta vez tu repositorio es **tuyo, desde cero**:

```
   Repo del curso            Tu repositorio             Tu instancia
   ──────────────            ──────────────             ────────────
   lo bajas una vez  ──▶  escribes en VS Code  ──push──▶  lo clonas
   (guías y esqueleto)         y haces push              y lo pruebas
```

Tres cosas que esto cambia respecto a la parte 1:

| | |
|---|---|
| **No hay fork** | Tu repositorio no depende del mío. Nada se desincroniza |
| **Tu repositorio es público** | Para que la instancia pueda clonarlo sin contraseñas ni tokens |
| **La instancia clona el tuyo** | No el del curso. Ahí pruebas lo que escribiste |

---

## 1. En tu computadora

| Qué | Dónde |
| --- | ----- |
| **git** | [git-scm.com](https://git-scm.com/downloads) |
| **VS Code** | [code.visualstudio.com](https://code.visualstudio.com/) |
| **Cuenta de GitHub** | [github.com](https://github.com/) |

```bash
git config --global user.name "Tu Nombre"
git config --global user.email "tu-correo@tec.mx"
```

### Si usas Windows: Git Bash como terminal de VS Code

**No es opcional.** VS Code en Windows abre PowerShell, y los comandos de este curso están
escritos para `bash`. En PowerShell, `./run start` falla así:

```
Error al ejecutar el programa 'run': La operación que se ha intentado no está permitida
```

Ya tienes bash: viene con Git for Windows. Solo hay que decirle a VS Code que lo use.

1. `Ctrl+Shift+P` → **Terminal: Select Default Profile** → **Git Bash**
2. Cierra la terminal abierta y abre una nueva

Compruébalo con `echo $SHELL`: tiene que terminar en `bash`.

---

## 2. Crea tu repositorio

En GitHub, **New repository**:

- Nombre: el que quieras. `TC3009-Part2` está bien.
- **Público.** No es un detalle: tu instancia lo va a clonar, y no tiene credenciales de
  GitHub. Un repositorio privado le pediría usuario y contraseña, y se quedaría colgado.
- **Sin** README, sin `.gitignore`, sin licencia. Vacío del todo.

Copia su URL. La vas a usar en el siguiente paso.

> **¿Y si no quiero que mi código sea público?** Entonces tendrías que generar un token de
> acceso personal y pegarlo en la instancia — una credencial tuya viviendo en una máquina
> compartida y desechable. Para este curso no vale la pena. Tu código no tiene secretos: las
> claves y las direcciones salen de variables de entorno, nunca del repositorio.

---

## 3. Baja el contenido del curso

Hay dos formas. **La primera es mejor** y solo tiene una línea más.

### Opción A — clonar y reapuntar (recomendada)

```bash
git clone https://github.com/vsosahdz/TC3009-Part2-2026.git
cd TC3009-Part2-2026

git remote rename origin curso
git remote add origin https://github.com/TU-USUARIO/TU-REPO.git
git push -u origin main
```

Cuatro comandos, y te dejan con lo mejor de los dos mundos: tu repositorio es tuyo, y
`curso` sigue ahí para traer correcciones sin depender de nada.

Compruébalo:

```bash
git remote -v
```

```
curso    https://github.com/vsosahdz/TC3009-Part2-2026.git (fetch)
origin   https://github.com/TU-USUARIO/TU-REPO.git (push)
```

### Opción B — el ZIP

Si te perdiste con lo anterior: en la página del repo del curso, **Code → Download ZIP**.
Descomprime, entra a la carpeta, y:

```bash
git init
git add -A
git commit -m "material del curso"
git branch -M main
git remote add origin https://github.com/TU-USUARIO/TU-REPO.git
git push -u origin main
```

Funciona igual, con una diferencia que se nota más adelante: **no tienes el remoto `curso`**,
así que si publico una corrección tienes que agregarlo a mano para traerla:

```bash
git remote add curso https://github.com/vsosahdz/TC3009-Part2-2026.git
```

---

## 4. Tu instancia

La misma t2.large de siempre. Si la tienes de la parte 1, sáltate crearla.

**En la instancia**, clona **tu** repositorio —no el del curso— y aprovisiona:

```bash
cd ~
git clone https://github.com/TU-USUARIO/TU-REPO.git
cd TU-REPO
bash setup/bootstrap.sh
```

El bootstrap instala Python, las dependencias, Ollama y el modelo. **La descarga del modelo
es de ~1 GB**, así que hazlo antes de la clase, no durante.

Luego:

```bash
./run start
./run salud
```

---

## El ciclo de trabajo

Es el mismo de la parte 1, cambiando de dónde clona la instancia:

```
   1. Editas en VS Code, en tu computadora
   2. git add -A && git commit -m "..." && git push
   3. En la instancia:  git pull && ./run restart
```

**Nunca edites en la instancia.** Lo que escribas ahí lo pisa el siguiente `git pull`, y no
está en tu repositorio, así que no cuenta como entregado.

---

## 5. Comprueba antes de la clase

- [ ] `git --version` responde
- [ ] Tu repositorio existe en GitHub, es **público**, y tiene el material
- [ ] `git remote -v` muestra `origin` (el tuyo) y, si usaste la opción A, `curso`
- [ ] En la instancia: `./run salud` dice algo
- [ ] En la instancia: `ollama list` muestra tu modelo
- [ ] **En Windows:** `echo $SHELL` termina en `bash`

---

## Problemas comunes

**`Support for password authentication was removed` al hacer push.**
GitHub no acepta contraseña. Usa un token de acceso personal como contraseña, o configura SSH.
Se hace una vez.

**La instancia se queda colgada pidiendo `Username for 'https://github.com'`.**
Tu repositorio es privado. Hazlo público en **Settings → General → Change visibility**.

**`./run` no se reconoce (Windows).**
Estás en PowerShell. Paso 1, Git Bash.

**`./run salud` dice que Ollama no responde.**
En la instancia: `ollama serve &`. Si acabas de reiniciarla, el servicio puede tardar.

**El modelo tarda muchísimo.**
Es una t2.large sin GPU: normal. La guía explica qué hacer con eso — y resulta que la
respuesta no es «un modelo más rápido».
