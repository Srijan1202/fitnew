"""Beta 3.7 (owner, 2026-10-25): turn the IFCT 2017, INDB and CoFID downloads
into the committed source files the seed builder reads (ifct2017.json,
indb.json, cofid.json).

    python -P database/seeds/food-sources/tools/convert_sources.py <raw dir>

<raw dir> holds ifct2017/compositions/index.csv (github.com/nodef/ifct2017)
and indb/INDB.xlsx, indb/recipes.xlsx, indb/recipes_servingsize.xlsx
(github.com/lindsayjaacks/Indian-Nutrient-Databank-INDB-) and
cofid/CoFID_2021.xlsx (gov.uk, "McCance and Widdowson's composition of foods
integrated dataset"; only the codes cofid-picks.json names). The raw files
are never committed; their SHA-256 is. Output is deterministic: the same
downloads always give the same two files. Needs openpyxl.

What is kept, and what is changed, is documented in ADR-036:
- IFCT: per 100 g, energy (kJ), protein, fat, available carbohydrate and
  total fibre, each with the standard deviation IFCT reports across regions;
  English and Hindi local names for search.
- INDB: each recipe's values per piece / bowl / cup as INDB serves it (the
  recipe's total over servings x pieces per serving: 8 idli from one idli
  recipe). INDB's own "per 100 g" is per 100 g of the RAW ingredients with
  the water added, not of the cooked dish, so it is kept for reference only.
  INDB counts the whole pan of oil in deep-fried recipes ("Oil, for deep
  frying, 240 ml"), which puts a medu vada at ~590 kcal; such recipes carry
  `deepFry` (the pan's oil as INDB weighs it, 1 g per ml, and the solids
  fried) so the builder leaves them out: the oil absorbed cannot be worked
  out reliably when the solids are measured in cups (ADR-036).
"""
import csv
import hashlib
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

import openpyxl

RAW = Path(sys.argv[1])
OUT = Path(__file__).resolve().parent.parent

IFCT_CITATION = (
    'Longvah, T., Ananthan, R., Bhaskarachary, K. and Venkaiah, K. (2017). Indian Food Composition Tables 2017. '
    'National Institute of Nutrition, Indian Council of Medical Research, Hyderabad, Telangana, India.'
)
IFCT_TERMS = (
    "NIN's notice permits personal use with acknowledgement and asks for written permission before the data is stored "
    'electronically to create a product. Used in FITOS by the owner\'s decision of 2026-10-25 without that permission '
    '(risk accepted; ADR-036). Machine-readable copy: github.com/nodef/ifct2017 (compositions/index.csv).'
)
INDB_CITATION = (
    'Vijayakumar, A., Jaacks, L. M. et al. (2024). Development of an Indian Food Composition Database. '
    'Current Developments in Nutrition 8(7):103790. doi:10.1016/j.cdnut.2024.103790. Data: '
    'github.com/lindsayjaacks/Indian-Nutrient-Databank-INDB-.'
)
COFID_CITATION = (
    "Public Health England (2021). McCance and Widdowson's The Composition of Foods Integrated Dataset 2021. "
    'gov.uk/government/publications/composition-of-foods-integrated-dataset-cofid. Contains public sector information '
    'licensed under the Open Government Licence v3.0.'
)
COFID_TERMS = 'Open Government Licence v3.0 (gov.uk copy): reuse, including commercial, with attribution. Crown copyright.'
INDB_TERMS = (
    'No licence is stated for the data, and its values derive mainly from IFCT 2017. Used in FITOS by the owner\'s '
    'decision of 2026-10-25 (risk accepted; ADR-036).'
)

# Local-name prefixes kept as search aliases (IFCT's `lang` column). English
# and Hindi only: the other languages' names start like common dishes
# (Telugu "dosakaya" is cucumber, and "dosa" found it).
LANGS = {'E.': 'English', 'H.': 'Hindi'}

# INDB weighs oil at 1 g per ml (its totals: 240 ml of oil = 240 g).
OIL_DENSITY = 1.0
UNIT_ML = {'ml': 1.0, 'c': 240.0, 'cup': 240.0, 'cups': 240.0, 'tbsp': 15.0, 'tsp': 5.0}
# Rough grams for the rest of INDB's units; they only size a deep-fried
# recipe's total weight, where the oil and the main solids dominate.
UNIT_GRAMS = {'sprig': 1.0, 'nos': 10.0, 'sheet': 5.0, 'drops': 0.05, 'pinch': 0.3, '': 5.0}
LIQUIDS = ('water', 'milk', 'curd', 'yoghurt', 'yogurt', 'juice', 'vinegar', 'sauce', 'buttermilk', 'stock')


def grams_of(name: str, unit: str, amount: float) -> float:
    """An ingredient's weight: g as is; volumes by density (fat 0.92,
    liquids 1.0, dry powders and spices ~0.6 g/ml); other units roughly."""
    if unit == 'g':
        return amount
    if unit in UNIT_ML:
        ml = amount * UNIT_ML[unit]
        if any(k in name for k in ('oil', 'ghee', 'vanaspati', 'butter')):
            return ml * OIL_DENSITY
        if any(k in name for k in LIQUIDS):
            return ml
        return ml * 0.6
    return amount * UNIT_GRAMS.get(unit, 5.0)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def num(v):
    if v in (None, ''):
        return None
    try:
        return float(v)
    except ValueError:
        return None


def r(v, d=2):
    return None if v is None else round(v + 0.0, d)


def local_names(lang: str) -> list[str]:
    out = []
    for part in lang.split(';'):
        part = part.strip().rstrip('.')
        for prefix in LANGS:
            if part.startswith(prefix + ' ') or part.startswith(prefix.rstrip('.') + ','):
                for name in part[len(prefix):].split(','):
                    name = re.sub(r'\(.*?\)', '', name).strip(' .')
                    if 2 <= len(name) <= 40 and name.lower() not in [o.lower() for o in out]:
                        out.append(name)
    return out


def ifct() -> dict:
    path = RAW / 'ifct2017' / 'compositions' / 'index.csv'
    foods = []
    with path.open(encoding='utf-8', newline='') as f:
        for row in csv.DictReader(f):
            foods.append({
                'code': row['code'],
                'name': row['name'].strip(),
                'group': row['grup'].strip(),
                'scientific': row['scie'].strip() or None,
                'localNames': local_names(row['lang']),
                'energyKj': r(num(row['enerc']), 1),
                'energyKjSd': r(num(row['enerc_e']), 1),
                'protein': r(num(row['protcnt'])),
                'proteinSd': r(num(row['protcnt_e'])),
                'fat': r(num(row['fatce'])),
                'fatSd': r(num(row['fatce_e'])),
                'carb': r(num(row['choavldf'])),
                'carbSd': r(num(row['choavldf_e'])),
                'fibre': r(num(row['fibtg'])),
                'fibreSd': r(num(row['fibtg_e'])),
            })
    foods.sort(key=lambda x: x['code'])
    return {
        'version': 1,
        'source': 'IFCT 2017',
        'citation': IFCT_CITATION,
        'terms': IFCT_TERMS,
        'raw': [{'file': 'ifct2017/compositions/index.csv', 'sha256': sha256(path)}],
        'foods': foods,
    }


def sheet(path: Path) -> list[dict]:
    wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
    rows = wb.worksheets[0].iter_rows(values_only=True)
    head = list(next(rows))
    return [dict(zip(head, row)) for row in rows]


def macro(d: dict, prefix: str = '') -> dict | None:
    kcal = num(d.get(f'{prefix}energy_kcal'))
    if kcal is None or kcal <= 0:
        return None
    return {
        'kcal': r(kcal, 1),
        'protein': r(num(d.get(f'{prefix}protein_g')) or 0.0),
        'carb': r(num(d.get(f'{prefix}carb_g')) or 0.0),
        'fat': r(num(d.get(f'{prefix}fat_g')) or 0.0),
        'fibre': r(num(d.get(f'{prefix}fibre_g'))),
    }


def indb() -> dict:
    files = {k: RAW / 'indb' / f for k, f in [('nut', 'INDB.xlsx'), ('ing', 'recipes.xlsx'), ('serv', 'recipes_servingsize.xlsx')]}
    nut = sheet(files['nut'])
    ing = defaultdict(list)
    for d in sheet(files['ing']):
        ing[d['recipe_code']].append(d)
    serv = {d['recipe_code']: d for d in sheet(files['serv'])}

    recipes = []
    for d in nut:
        code = d['food_code']
        per100 = macro(d)
        if per100 is None:
            continue
        s = serv.get(code, {})
        servings = num(s.get('no_of_servings'))
        size = num(s.get('size_of_servings'))
        units = None if servings is None or size is None else servings * size
        per_unit = macro(d, 'unit_serving_')
        unit = (d.get('servings_unit') or s.get('servings_unit') or '').strip() or None
        oil = 0.0
        solids = 0.0
        total = 0.0
        deep = False
        for i in ing.get(code, []):
            name = str(i.get('food_name') or '').lower()
            org = str(i.get('amount_org') or '').lower()
            unit_i = str(i.get('unit') or '').lower()
            amount = num(i.get('amount')) or 0.0
            total += grams_of(name, unit_i, amount)
            is_fat = any(k in name for k in ('oil', 'ghee', 'vanaspati'))
            if is_fat and ('fry' in org or (unit_i == 'ml' and amount >= 100)):
                deep = True
            if is_fat:
                grams = amount if unit_i == 'g' else amount * UNIT_ML.get(unit_i, 0.0) * OIL_DENSITY
                oil += grams
            elif unit_i == 'g' and 'water' not in name:
                solids += amount
        recipes.append({
            'code': code,
            'name': str(d['food_name']).strip(),
            'origin': d.get('primarysource'),
            'per100gRaw': per100,
            'perUnit': None if per_unit is None or unit is None or not units else {'unit': unit, 'unitsInRecipe': r(units, 2), **per_unit},
            'deepFry': {'oilGrams': r(oil, 1), 'solidsGrams': r(solids, 1), 'rawGrams': r(total, 1)} if deep else None,
        })
    recipes.sort(key=lambda x: x['code'])
    return {
        'version': 1,
        'source': 'INDB 2024',
        'citation': INDB_CITATION,
        'terms': INDB_TERMS,
        'raw': [{'file': f'indb/{p.name}', 'sha256': sha256(p)} for p in files.values()],
        'recipes': recipes,
    }


def cofid_value(v):
    """CoFID marks trace as 'Tr' (0) and not measured as 'N' (unknown)."""
    if v in (None, '', 'N'):
        return None
    if v == 'Tr':
        return 0.0
    return r(num(str(v)))


def cofid() -> dict:
    path = RAW / 'cofid' / 'CoFID_2021.xlsx'
    picks = json.loads((OUT / 'cofid-picks.json').read_text(encoding='utf-8'))
    codes = {p['code'] for p in picks['replace']} | {f['code'] for f in picks['foods']}
    wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
    rows = wb['1.3 Proximates'].iter_rows(values_only=True)
    head = next(rows)
    next(rows)
    next(rows)
    col = {name: head.index(name) for name in ('Food Code', 'Food Name', 'Protein (g)', 'Fat (g)', 'Carbohydrate (g)', 'Energy (kcal) (kcal)', 'NSP (g)', 'AOAC fibre (g)')}
    foods = []
    for row in rows:
        code = row[col['Food Code']]
        if code not in codes:
            continue
        aoac = cofid_value(row[col['AOAC fibre (g)']])
        foods.append({
            'code': code,
            'name': str(row[col['Food Name']]).strip(),
            'kcal': cofid_value(row[col['Energy (kcal) (kcal)']]),
            'protein': cofid_value(row[col['Protein (g)']]),
            'carb': cofid_value(row[col['Carbohydrate (g)']]),
            'fat': cofid_value(row[col['Fat (g)']]),
            'fibre': aoac if aoac is not None else cofid_value(row[col['NSP (g)']]),
        })
    missing = codes - {f['code'] for f in foods}
    if missing:
        raise SystemExit(f'CoFID codes not found: {sorted(missing)}')
    foods.sort(key=lambda x: x['code'])
    return {
        'version': 1,
        'source': 'CoFID 2021',
        'citation': COFID_CITATION,
        'terms': COFID_TERMS,
        'raw': [{'file': 'cofid/CoFID_2021.xlsx', 'sha256': sha256(path)}],
        'foods': foods,
    }


def write(name: str, value: dict) -> None:
    text = json.dumps(value, ensure_ascii=False, indent=2) + '\n'
    (OUT / name).write_text(text, encoding='utf-8', newline='\n')
    print(f'{name}: {len(value.get("foods", value.get("recipes", [])))} entries')


write('ifct2017.json', ifct())
write('indb.json', indb())
write('cofid.json', cofid())
