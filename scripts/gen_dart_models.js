#!/usr/bin/env node
/**
 * gen_dart_models.js
 *
 * Reads openapi.json (OpenAPI 3.x) and generates Dart model classes from
 * the components/schemas section. Output goes to lib/core/models/generated/.
 *
 * Usage:
 *   node scripts/gen_dart_models.js [--spec ../openapi.json] [--out lib/core/models/generated]
 *
 * The generated file is a single models_generated.dart that exports one class
 * per schema object.  Primitive enums get a Dart enum, objects get a class with
 * fromJson / toJson.
 */

'use strict';

const fs   = require('fs');
const path = require('path');

// ── CLI args ──────────────────────────────────────────────────────────────────
const args = process.argv.slice(2);
function getArg(flag, def) {
  const i = args.indexOf(flag);
  return i !== -1 && args[i + 1] ? args[i + 1] : def;
}

const SPEC_PATH = getArg('--spec', path.resolve(__dirname, '../../textile-erp-backend/openapi.json'));
const OUT_DIR   = getArg('--out',  path.resolve(__dirname, '../lib/core/models/generated'));

if (!fs.existsSync(SPEC_PATH)) {
  console.error(`ERROR: spec not found at ${SPEC_PATH}`);
  console.error('Run "npm run export-spec" in the backend first.');
  process.exit(1);
}

const spec    = JSON.parse(fs.readFileSync(SPEC_PATH, 'utf8'));
const schemas = (spec.components || {}).schemas || {};

fs.mkdirSync(OUT_DIR, { recursive: true });

// ── Type mapping ──────────────────────────────────────────────────────────────
/** Map OpenAPI primitive type+format to Dart type string. */
function primitiveType(prop) {
  const t = prop.type;
  const f = prop.format || '';
  if (t === 'integer')                 return 'int';
  if (t === 'number')                  return 'double';
  if (t === 'boolean')                 return 'bool';
  if (t === 'string' && f === 'date-time') return 'String'; // keep as ISO string
  if (t === 'string')                  return 'String';
  return 'dynamic';
}

/**
 * Resolve a property definition to a Dart type string.
 * Returns { type: String, isList: bool, refName: String|null }
 */
function dartType(prop, required) {
  if (!prop) return { type: 'dynamic', nullable: true };

  // $ref
  if (prop.$ref) {
    const refName = prop.$ref.split('/').pop();
    const nullable = !required;
    return { type: schemaName(refName), nullable };
  }

  // allOf with single $ref (NestJS sometimes wraps this way)
  if (prop.allOf && prop.allOf.length === 1 && prop.allOf[0].$ref) {
    const refName = prop.allOf[0].$ref.split('/').pop();
    return { type: schemaName(refName), nullable: !required };
  }

  // array
  if (prop.type === 'array') {
    const inner = prop.items ? dartType(prop.items, true) : { type: 'dynamic', nullable: false };
    return { type: `List<${inner.type}>`, nullable: false, isList: true };
  }

  // enum → treat as String (generate a separate enum class if needed)
  if (prop.enum) {
    return { type: 'String', nullable: !required };
  }

  return { type: primitiveType(prop), nullable: !required };
}

/** Convert schema name to valid Dart class name (PascalCase). */
function schemaName(name) {
  // Already PascalCase in most NestJS setups, but normalise anyway.
  return name.replace(/(?:^|[-_])(\w)/g, (_, c) => c.toUpperCase());
}

/** Convert property key to Dart lowerCamelCase field name. */
function fieldName(key) {
  return key.replace(/[-_](\w)/g, (_, c) => c.toUpperCase());
}

// ── Code generators ───────────────────────────────────────────────────────────
function generateEnum(name, values) {
  const dartName = schemaName(name);
  const entries  = values.map(v => `  ${fieldName(String(v))}`).join(',\n');
  return `
enum ${dartName} {
${entries};

  static ${dartName} fromJson(String v) =>
      ${dartName}.values.firstWhere((e) => e.name == v,
          orElse: () => throw ArgumentError('Unknown ${dartName}: \$v'));

  String toJson() => name;
}
`.trimStart();
}

function generateClass(name, schema) {
  const dartName  = schemaName(name);
  const props     = schema.properties || {};
  const requiredSet = new Set(schema.required || []);

  const fields    = [];
  const ctorArgs  = [];
  const fromJson  = [];
  const toJson    = [];

  for (const [key, prop] of Object.entries(props)) {
    const isRequired = requiredSet.has(key);
    const { type, nullable } = dartType(prop, isRequired);
    const fn   = fieldName(key);
    const q    = nullable ? '?' : '';
    const req  = nullable ? '' : 'required ';

    fields.push(`  final ${type}${q} ${fn};`);
    ctorArgs.push(`    ${req}this.${fn},`);

    // fromJson
    if (type === 'int') {
      fromJson.push(`    ${fn}: (j['${key}'] as num?)?.toInt()${isRequired ? ' ?? 0' : ''},`);
    } else if (type === 'double') {
      fromJson.push(`    ${fn}: (j['${key}'] as num?)?.toDouble()${isRequired ? ' ?? 0.0' : ''},`);
    } else if (type === 'bool') {
      fromJson.push(`    ${fn}: j['${key}'] as bool${isRequired ? '? ?? false' : '?'},`);
    } else if (type.startsWith('List<')) {
      const innerMatch = type.match(/List<(.+)>/);
      const innerType  = innerMatch ? innerMatch[1] : 'dynamic';
      const isPrimitive = ['String','int','double','bool','dynamic'].includes(innerType);
      if (isPrimitive) {
        fromJson.push(`    ${fn}: (j['${key}'] as List<dynamic>? ?? []).cast<${innerType}>(),`);
      } else {
        fromJson.push(`    ${fn}: (j['${key}'] as List<dynamic>? ?? [])
        .map((e) => ${innerType}.fromJson(e as Map<String, dynamic>))
        .toList(),`);
      }
    } else if (['String', 'dynamic'].includes(type)) {
      // 'dynamic' is already nullable; don't emit 'dynamic?'
      const castSuffix = type === 'dynamic' ? '' : '?';
      fromJson.push(`    ${fn}: j['${key}'] as ${type}${castSuffix}${isRequired ? (type === 'dynamic' ? '' : ' ?? \'\'') : ''},`);
    } else {
      // nested object ref
      if (nullable) {
        fromJson.push(`    ${fn}: j['${key}'] != null ? ${type}.fromJson(j['${key}'] as Map<String, dynamic>) : null,`);
      } else {
        fromJson.push(`    ${fn}: ${type}.fromJson(j['${key}'] as Map<String, dynamic>),`);
      }
    }

    // toJson
    if (type.startsWith('List<')) {
      const innerMatch = type.match(/List<(.+)>/);
      const innerType  = innerMatch ? innerMatch[1] : 'dynamic';
      const isPrimitive = ['String','int','double','bool','dynamic'].includes(innerType);
      if (isPrimitive) {
        toJson.push(`      '${key}': ${fn},`);
      } else {
        toJson.push(`      '${key}': ${fn}.map((e) => e.toJson()).toList(),`);
      }
    } else if (['String','int','double','bool','dynamic'].includes(type)) {
      toJson.push(`      '${key}': ${fn},`);
    } else {
      toJson.push(`      '${key}': ${fn}${nullable ? '?' : ''}.toJson(),`);
    }
  }

  return `
class ${dartName} {
${fields.join('\n')}

  const ${dartName}({
${ctorArgs.join('\n')}
  });

  factory ${dartName}.fromJson(Map<String, dynamic> j) => ${dartName}(
${fromJson.join('\n')}
  );

  Map<String, dynamic> toJson() => {
${toJson.join('\n')}
  };
}
`.trimStart();
}

// ── Generate all schemas ──────────────────────────────────────────────────────
const parts = [
  '// GENERATED FILE \u2014 DO NOT EDIT BY HAND',
  '// Run: bash codegen.sh',
  '// Source: openapi.json (auto-exported from NestJS backend)',
  '',
  "// ignore_for_file: unnecessary_null_comparison",
  '',
];

const generated = { enums: [], classes: [] };

for (const [name, schema] of Object.entries(schemas)) {
  if (schema.enum) {
    parts.push(generateEnum(name, schema.enum));
    generated.enums.push(schemaName(name));
  } else if (schema.type === 'object' || schema.properties) {
    parts.push(generateClass(name, schema));
    generated.classes.push(schemaName(name));
  }
  // Skip schemas that are just primitives or have no properties
}

const outFile = path.join(OUT_DIR, 'models_generated.dart');
fs.writeFileSync(outFile, parts.join('\n'));

console.log(`\u2713 Generated ${generated.classes.length} classes, ${generated.enums.length} enums`);
console.log(`  \u2192 ${outFile}`);
console.log(`  Classes: ${generated.classes.join(', ')}`);
