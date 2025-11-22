// CSS extractor
// Supports: rules, keyframes, media queries, variables

const { TreeSitterExtractor } = require('./base-extractor');

class CSSExtractor extends TreeSitterExtractor {
  constructor() {
    super('css');
  }

  processNode(node, ancestors) {
    switch (node.type) {
      case 'rule_set':
        // CSS rules like .class { ... } or #id { ... }
        const selectors = node.childForFieldName('selectors');
        if (selectors) {
          const selectorText = selectors.text.trim();
          if (selectorText) {
            this.addSegment(node, 'rule', selectorText, ancestors);
          }
        }
        break;

      case 'keyframes_statement':
        // @keyframes animation-name { ... }
        const keyframeName = node.childForFieldName('name')?.text;
        if (keyframeName) {
          this.addSegment(node, 'keyframes', keyframeName, ancestors);
        }
        break;

      case 'media_statement':
        // @media (condition) { ... }
        const query = node.childForFieldName('query');
        if (query) {
          const queryText = query.text.trim();
          this.addSegment(node, 'media_query', queryText, ancestors);
        }
        break;

      case 'declaration':
        // CSS custom properties (variables): --var-name: value;
        const property = node.childForFieldName('property');
        if (property && property.text.startsWith('--')) {
          const varName = property.text;
          this.addSegment(node, 'css_variable', varName, ancestors);
        }
        break;

      case 'import_statement':
        // @import url(...);
        const importPath = node.text.replace('@import', '').trim();
        if (importPath) {
          this.addSegment(node, 'import', importPath, ancestors);
        }
        break;

      case 'namespace_statement':
        // @namespace prefix url(...);
        const namespace = node.text.replace('@namespace', '').trim();
        if (namespace) {
          this.addSegment(node, 'namespace', namespace, ancestors);
        }
        break;

      case 'supports_statement':
        // @supports (condition) { ... }
        const condition = node.childForFieldName('condition');
        if (condition) {
          this.addSegment(node, 'supports', condition.text.trim(), ancestors);
        }
        break;
    }
  }
}

// Register processor
function processCSSNode(node, ancestors, extractor) {
  const cssExtractor = new CSSExtractor();
  cssExtractor.processNode(node, ancestors);
}

TreeSitterExtractor.register('css', processCSSNode);

module.exports = {
  CSSExtractor,
  processCSSNode
};
