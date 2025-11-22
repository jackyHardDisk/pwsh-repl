// Python extractor
// Extracted from vibe_tools for loraxMod

const { TreeSitterExtractor } = require('./base-extractor');

class PythonExtractor extends TreeSitterExtractor {
  constructor() {
    super('python');
  }

  processNode(node, ancestors) {
    switch (node.type) {
      case 'class_definition':
        const className = node.childForFieldName('name')?.text;
        const superClass = node.childForFieldName('superclasses')?.firstChild?.text;
        if (className) {
          this.addSegment(node, 'class', className, ancestors, { extends: superClass });
        }
        break;

      case 'function_definition':
        const functionName = node.childForFieldName('name')?.text;
        if (functionName) {
          // Use ancestors to determine if this is a method or function
          const isInClass = ancestors.some(ancestor => ancestor.type === 'class_definition');
          const type = isInClass ? 'method' : 'function';
          this.addSegment(node, type, functionName, ancestors);
        }
        break;

      case 'assignment':
        // Handle constants (uppercase variables at module level)
        const target = node.childForFieldName('left');
        const varName = target?.text;

        if (varName && /^[A-Z][A-Z_0-9]*$/.test(varName)) {
          const isTopLevel = !ancestors.some(ancestor =>
            ancestor.type === 'function_definition' || ancestor.type === 'class_definition'
          );

          if (isTopLevel) {
            this.addSegment(node, 'constant', varName, ancestors);
          }
        }
        break;

      case 'global_statement':
        // Handle global variable declarations
        const globalVar = node.firstChild?.nextSibling?.text;
        if (globalVar) {
          this.addSegment(node, 'global', globalVar, ancestors);
        }
        break;
    }
  }
}

// Register processor
function processPythonNode(node, ancestors, extractor) {
  const pyExtractor = new PythonExtractor();
  pyExtractor.processNode(node, ancestors);
}

TreeSitterExtractor.register('python', processPythonNode);

module.exports = {
  PythonExtractor,
  processPythonNode
};
