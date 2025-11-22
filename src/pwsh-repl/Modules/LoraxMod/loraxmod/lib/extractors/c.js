// C extractor
// Supports: functions, structs, enums, unions, typedefs, macros

const { TreeSitterExtractor } = require('./base-extractor');

class CExtractor extends TreeSitterExtractor {
  constructor() {
    super('c');
  }

  processNode(node, ancestors) {
    switch (node.type) {
      case 'function_definition':
        const funcDeclarator = node.childForFieldName('declarator');
        const funcName = this.extractFunctionName(funcDeclarator);
        if (funcName) {
          this.addSegment(node, 'function', funcName, ancestors);
        }
        break;

      case 'declaration':
        // Handle function declarations (prototypes)
        const declarator = node.childForFieldName('declarator');
        if (declarator && declarator.type === 'function_declarator') {
          const protoName = this.extractFunctionName(declarator);
          if (protoName) {
            this.addSegment(node, 'function_prototype', protoName, ancestors);
          }
        }

        // Handle variable declarations (check for constants)
        const typeNode = node.childForFieldName('type');
        if (typeNode && typeNode.text.includes('const')) {
          const declName = this.extractDeclaratorName(declarator);
          if (declName) {
            this.addSegment(node, 'constant', declName, ancestors);
          }
        }
        break;

      case 'struct_specifier':
        const structName = node.childForFieldName('name')?.text;
        if (structName) {
          this.addSegment(node, 'struct', structName, ancestors);
        }
        break;

      case 'enum_specifier':
        const enumName = node.childForFieldName('name')?.text;
        if (enumName) {
          this.addSegment(node, 'enum', enumName, ancestors);
        }
        break;

      case 'union_specifier':
        const unionName = node.childForFieldName('name')?.text;
        if (unionName) {
          this.addSegment(node, 'union', unionName, ancestors);
        }
        break;

      case 'type_definition':
        // typedef handling
        const typedefDeclarator = node.childForFieldName('declarator');
        const typedefName = this.extractDeclaratorName(typedefDeclarator);
        if (typedefName) {
          this.addSegment(node, 'typedef', typedefName, ancestors);
        }
        break;

      case 'preproc_def':
      case 'preproc_function_def':
        // #define macros
        const macroName = node.childForFieldName('name')?.text;
        if (macroName) {
          const macroType = node.type === 'preproc_function_def' ? 'macro_function' : 'macro';
          this.addSegment(node, macroType, macroName, ancestors);
        }
        break;
    }
  }

  // Helper to extract function name from declarator
  extractFunctionName(declarator) {
    if (!declarator) return null;

    if (declarator.type === 'function_declarator') {
      const inner = declarator.childForFieldName('declarator');
      return this.extractDeclaratorName(inner);
    }

    return this.extractDeclaratorName(declarator);
  }

  // Helper to extract name from various declarator types
  extractDeclaratorName(declarator) {
    if (!declarator) return null;

    if (declarator.type === 'identifier') {
      return declarator.text;
    }

    if (declarator.type === 'pointer_declarator') {
      const inner = declarator.childForFieldName('declarator');
      return this.extractDeclaratorName(inner);
    }

    if (declarator.type === 'array_declarator') {
      const inner = declarator.childForFieldName('declarator');
      return this.extractDeclaratorName(inner);
    }

    if (declarator.type === 'function_declarator') {
      const inner = declarator.childForFieldName('declarator');
      return this.extractDeclaratorName(inner);
    }

    return null;
  }
}

// Register processor
function processCNode(node, ancestors, extractor) {
  const cExtractor = new CExtractor();
  cExtractor.processNode(node, ancestors);
}

TreeSitterExtractor.register('c', processCNode);

module.exports = {
  CExtractor,
  processCNode
};
