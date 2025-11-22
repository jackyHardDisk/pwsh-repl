// JavaScript/TypeScript extractor
// Extracted from vibe_tools for loraxMod

const { TreeSitterExtractor } = require('./base-extractor');

class JavaScriptExtractor extends TreeSitterExtractor {
  constructor() {
    super('javascript');
  }

  processNode(node, ancestors) {
    switch (node.type) {
      case 'class_declaration':
        const className = node.childForFieldName('name')?.text;
        const superClass = node.childForFieldName('superclass')?.text;
        if (className) {
          this.addSegment(node, 'class', className, ancestors, { extends: superClass });
        }
        break;

      case 'method_definition':
        const methodName = node.childForFieldName('name')?.text;
        if (methodName) {
          this.addSegment(node, 'method', methodName, ancestors);
        }
        break;

      case 'function_declaration':
        const functionName = node.childForFieldName('name')?.text;
        if (functionName) {
          this.addSegment(node, 'function', functionName, ancestors);
        }
        break;

      case 'lexical_declaration':
        // Handle const declarations
        if (node.firstChild?.text === 'const') {
          const declarator = node.childForFieldName('declarator');
          const constName = declarator?.childForFieldName('name')?.text;

          if (constName && !this.shouldExcludeConstant(constName)) {
            // Use ancestors to check if we're at top level
            const isTopLevel = !ancestors.some(ancestor =>
              ancestor.type === 'function_declaration' ||
              ancestor.type === 'arrow_function' ||
              ancestor.type === 'function_expression'
            );

            if (isTopLevel) {
              this.addSegment(node, 'constant', constName, ancestors);
            }
          }
        }
        break;

      case 'assignment_expression':
        // Handle global assignments like window.something =
        const left = node.childForFieldName('left');
        if (left?.type === 'member_expression') {
          const object = left.childForFieldName('object')?.text;
          const property = left.childForFieldName('property')?.text;

          if ((object === 'window' || object === 'global') && property) {
            this.addSegment(node, 'global', property, ancestors);
          }
        }
        break;

      case 'export_statement':
        // Handle export declarations
        const exported = node.childForFieldName('declaration');
        if (exported) {
          const exportName = this.getExportedName(exported);
          if (exportName) {
            this.addSegment(node, 'export', exportName, ancestors);
          }
        }
        break;
    }
  }

  getExportedName(exportNode) {
    // Extract name from various export patterns
    if (exportNode.type === 'function_declaration') {
      return exportNode.childForFieldName('name')?.text;
    } else if (exportNode.type === 'class_declaration') {
      return exportNode.childForFieldName('name')?.text;
    } else if (exportNode.type === 'lexical_declaration') {
      const declarator = exportNode.childForFieldName('declarator');
      return declarator?.childForFieldName('name')?.text;
    }
    return 'default';
  }
}

// Register processor
function processJavaScriptNode(node, ancestors, extractor) {
  const jsExtractor = new JavaScriptExtractor();
  jsExtractor.processNode(node, ancestors);
}

TreeSitterExtractor.register('javascript', processJavaScriptNode);

module.exports = {
  JavaScriptExtractor,
  processJavaScriptNode
};
