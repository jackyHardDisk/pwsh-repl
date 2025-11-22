// Rust extractor
// Supports: structs, enums, traits, impl blocks, functions, modules, constants, macros

const { TreeSitterExtractor } = require('./base-extractor');

class RustExtractor extends TreeSitterExtractor {
  constructor() {
    super('rust');
  }

  processNode(node, ancestors) {
    switch (node.type) {
      case 'struct_item':
        const structName = node.childForFieldName('name')?.text;
        if (structName) {
          this.addSegment(node, 'struct', structName, ancestors);
        }
        break;

      case 'enum_item':
        const enumName = node.childForFieldName('name')?.text;
        if (enumName) {
          this.addSegment(node, 'enum', enumName, ancestors);
        }
        break;

      case 'trait_item':
        const traitName = node.childForFieldName('name')?.text;
        if (traitName) {
          this.addSegment(node, 'trait', traitName, ancestors);
        }
        break;

      case 'impl_item':
        // impl blocks can be:
        // 1. impl StructName { ... } - inherent implementation
        // 2. impl TraitName for StructName { ... } - trait implementation
        const typeName = node.childForFieldName('type')?.text;
        const traitNode = node.childForFieldName('trait');

        let implName = typeName || 'Unknown';
        let implType = 'impl';

        if (traitNode) {
          const traitText = traitNode.text;
          implName = `${traitText} for ${typeName || 'Unknown'}`;
          implType = 'trait_impl';
        }

        if (implName) {
          this.addSegment(node, implType, implName, ancestors);
        }
        break;

      case 'function_item':
        const funcName = node.childForFieldName('name')?.text;
        if (funcName) {
          // Check if this is inside an impl block (method) or top-level (function)
          const inImpl = ancestors.some(a => a.type === 'impl_item');
          const segmentType = inImpl ? 'method' : 'function';
          this.addSegment(node, segmentType, funcName, ancestors);
        }
        break;

      case 'mod_item':
        const modName = node.childForFieldName('name')?.text;
        if (modName) {
          this.addSegment(node, 'module', modName, ancestors);
        }
        break;

      case 'const_item':
        const constName = node.childForFieldName('name')?.text;
        if (constName) {
          this.addSegment(node, 'constant', constName, ancestors);
        }
        break;

      case 'static_item':
        const staticName = node.childForFieldName('name')?.text;
        if (staticName) {
          this.addSegment(node, 'static', staticName, ancestors);
        }
        break;

      case 'type_item':
        const typeDef = node.childForFieldName('name')?.text;
        if (typeDef) {
          this.addSegment(node, 'type_alias', typeDef, ancestors);
        }
        break;

      case 'macro_definition':
        // Declarative macros: macro_rules! name { ... }
        const macroName = node.childForFieldName('name')?.text;
        if (macroName) {
          this.addSegment(node, 'macro', macroName, ancestors);
        }
        break;

      case 'union_item':
        const unionName = node.childForFieldName('name')?.text;
        if (unionName) {
          this.addSegment(node, 'union', unionName, ancestors);
        }
        break;

      case 'extern_crate_declaration':
        const crateName = node.childForFieldName('name')?.text;
        if (crateName) {
          this.addSegment(node, 'extern_crate', crateName, ancestors);
        }
        break;

      case 'use_declaration':
        // Track use statements for context but don't extract as segments
        // Could be useful for finding imports
        break;
    }
  }
}

// Register processor
function processRustNode(node, ancestors, extractor) {
  const rustExtractor = new RustExtractor();
  rustExtractor.processNode(node, ancestors);
}

TreeSitterExtractor.register('rust', processRustNode);

module.exports = {
  RustExtractor,
  processRustNode
};
