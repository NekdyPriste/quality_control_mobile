### **Dokumentace: Kompletní průvodce pro kontrolu prototypů pomocí AI**

Tento dokument popisuje, jak krok za krokem vybudovat automatizovaný systém pro vizuální kontrolu prototypů. Systém využívá 3D model jako referenci a umělou inteligenci k analýze skutečných výlisků.

#### **1. Přehled architektury**

Systém se skládá ze tří hlavních částí:

  * **Mobilní aplikace (klient):** Pro nahrávání 3D modelu a fotografií.
  * **Cloudový server (backend):** Provádí veškeré výpočty – generování dat, trénink AI a analýzu.
  * **Gemini API:** Poskytuje doplňkovou, inteligentní analýzu nalezených vad.

#### **2. Průběh analýzy**

1.  **Nahrání dat:** Uživatel nahraje **3D model** a pořídí **více fotografií** prototypu. Aplikace odešle data na cloudový server.
2.  **Generování syntetických dat:** Server použije **BlenderProc** k automatickému vytvoření stovek dokonalých snímků z 3D modelu.
3.  **Trénink modelu:** Snímky se použijí k **rychlému tréninku** modelu PatchCore (pomocí Anomalib).
4.  **Analýza:** Natrénovaný model analyzuje fotografie a vytvoří **mapu anomálií**, která ukáže a lokalizuje vady.
5.  **Doplňková analýza od Gemini:** Server odešle obrázek vady do Gemini API, které poskytne **textový popis** a možný dopad vady.
6.  **Report:** Všechny výsledky se zkombinují do finálního reportu a odešlou zpět do mobilní aplikace.

-----

#### **3. Detailní implementace**

##### **3.1. Cloudová infrastruktura (AWS, Google Cloud)**

  * **Výběr instance:** Použij **GPU instanci** s dostatečným výkonem pro rychlé renderování a trénink (např. **AWS EC2 G5 s GPU NVIDIA A10G**).
  * **Nastavení prostředí:**
      * Nainstaluj **OS (Linux)**, **NVIDIA GPU ovladače** a **Docker**.
      * Vytvoř **Docker image** s předinstalovaným **Pythonem**, **Blenderem**, **BlenderProc** a **Anomalib**. To zajistí, že celé prostředí je přenosné a snadno se spouští.

##### **3.2. Backendový skript (Python)**

Vytvoř hlavní Python skript, který bude řídit celý proces.

1.  **Příjem dat:** Skript začne naslouchat API endpointu, kam mobilní aplikace posílá data.
2.  **Spuštění BlenderProc:** Spusť Blender v **headless módu** pro renderování.
    ```python
    import subprocess
    # Spustí BlenderProc skript pro generování dat
    subprocess.run(['blenderproc', 'run', 'script.py', '--input_model', 'model.obj'])
    ```
3.  **Trénink PatchCore:** Použij Anomalib pro trénink. Je klíčové využít **přenosové učení** pro urychlení.
    ```python
    from anomalib.models import Patchcore
    from anomalib.data import BDDDataset

    # Načtení dat z vyrenderovaných snímků
    dataset = BDDDataset(root='/path/to/synthetic_images', task='segmentation')

    # Trénink modelu (použije se předtrénovaný ResNet)
    model = Patchcore(backbone='resnet18')
    model.fit(dataset)
    model.save('trained_model.pt')
    ```
4.  **Analýza reálných snímků:**
      * Načti natrénovaný model.
      * Pro každý snímek z telefonu proveď detekci anomálií a vygeneruj mapu.
5.  **Integrace s Gemini API:**
      * Připoj se k Gemini API a odešli obrázek s vadou a dotazem.
    <!-- end list -->
    ```python
    import google.generativeai as genai
    genai.configure(api_key="YOUR_API_KEY")

    # Pošli obrázek s vadou
    image_part = genai.Image.from_path('anomaly_map.png')

    response = genai.generate_content([
        "Analyzuj tuto vadu na obrázku. Jaký typ defektu to je?",
        image_part
    ])
    print(response.text) # Gemini ti pošle popis
    ```
6.  **Odeslání reportu:** Zabal všechny výsledky (skóre, mapy vad, text z Gemini) do jednoho JSON objektu a odešli zpět do aplikace.

-----

#### **4. Odhadované náklady a provoz**

Při průměru **dvou analýz denně** budou měsíční náklady vypadat následovně:

  * **GPU instance:** 2 analýzy \* 15 minut (0.25 hod) \* 30 dní = 15 hodin měsíčně.
      * Při ceně **$1.01/hod** (AWS A10G) je to: 15 \* 1.01 = **$15.15 měsíčně**.
  * **Gemini API:** 2 analýzy \* 1 obrázek \* 30 dní = 60 obrázků.
      * Při ceně **$0.0025/obrázek** je to: 60 \* 0.0025 = **$0.15 měsíčně**.
  * **Úložiště, přenos dat:** Zanedbatelné, ale počítej s **$5 - $10 měsíčně**.

**Celkové měsíční náklady:** **\~ $25 - $30**.

Toto řešení je sice složitější na nastavení, ale díky nízké frekvenci použití je cenově udržitelné a nabízí vysokou přidanou hodnotu.