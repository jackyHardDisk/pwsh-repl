// C++ extractor
// Supports: classes, namespaces, templates, functions (inherits from C)

const { CExtractor } = require('./c');
const { TreeSitterExtractor } = require('./base-extractor');

class CPPExtractor extends CExtractor {
  constructor() {
    super();
    this.language = 'cpp';
  }

  processNode(node, ancestors) {
    // Handle C++-specific nodes first
    switch (node.type) {
      case 'class_specifier':
        const className = node.childForFieldName('name')?.text;
        if (className) {
          this.addSegment(node, 'class', className, ancestors);
        }
        break;

      case 'namespace_definition':
        const namespaceName = node.childForFieldName('name')?.text;
        if (namespaceName) {
          this.addSegment(node, 'namespace', namespaceName, ancestors);
        }
        break;

      case 'template_declaration':
        // Templates wrapping functions or classes
        const templateBody = node.children.find(c =>
          c.type === 'function_definition' || c.type === 'class_specifier'
        );
        if (templateBody) {
          // Let parent class handle it, but mark as template
          super.processNode(templateBody, ancestors);
        }
        break;

      default:
        // Fallback to C extractor for common nodes
        super.processNode(node, ancestors);
        break;
    }
  }
}

// Register processor
function processCPPNode(node, ancestors, extractor) {
  const cppExtractor = new CPPExtractor();
  cppExtractor.processNode(node, ancestors);
}

TreeSitterExtractor.register('cpp', processCPPNode);

module.exports = {
  CPPExtractor,
  processCPPNode
};
