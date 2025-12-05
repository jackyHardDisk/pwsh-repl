// HTML extractor
// Minimal implementation - focuses on embedded code blocks and semantic landmarks

const { TreeSitterExtractor } = require('./base-extractor');

class HTMLExtractor extends TreeSitterExtractor {
  constructor() {
    super('html');
  }

  processNode(node, ancestors) {
    switch (node.type) {
      case 'script_element':
        // Extract inline JavaScript blocks
        const scriptContent = this.getElementContent(node);
        if (scriptContent && scriptContent.trim().length > 0) {
          const scriptId = this.getElementId(node) || 'inline-script';
          this.addSegment(node, 'script_block', scriptId, ancestors);
        }
        break;

      case 'style_element':
        // Extract inline CSS blocks
        const styleContent = this.getElementContent(node);
        if (styleContent && styleContent.trim().length > 0) {
          const styleId = this.getElementId(node) || 'inline-style';
          this.addSegment(node, 'style_block', styleId, ancestors);
        }
        break;

      case 'element':
        // Extract elements with id attribute (semantic landmarks)
        const startTag = node.childForFieldName('start_tag');
        if (startTag) {
          const idAttr = this.findAttribute(startTag, 'id');
          if (idAttr) {
            const tagName = this.getTagName(startTag);
            const elementName = `${tagName}#${idAttr}`;
            this.addSegment(node, 'element', elementName, ancestors);
          }
        }
        break;
    }
  }

  /**
   * Get text content from element
   */
  getElementContent(elementNode) {
    for (const child of elementNode.children) {
      if (child.type === 'text' || child.type === 'raw_text') {
        return child.text;
      }
    }
    return '';
  }

  /**
   * Get id attribute from element (if any)
   */
  getElementId(elementNode) {
    const startTag = elementNode.childForFieldName('start_tag');
    return startTag ? this.findAttribute(startTag, 'id') : null;
  }

  /**
   * Get tag name from start_tag node
   */
  getTagName(startTagNode) {
    const nameNode = startTagNode.childForFieldName('name');
    return nameNode ? nameNode.text : 'unknown';
  }

  /**
   * Find attribute value by name
   */
  findAttribute(startTagNode, attrName) {
    const attributes = startTagNode.children.filter(child => child.type === 'attribute');

    for (const attr of attributes) {
      const name = attr.childForFieldName('name')?.text;
      if (name === attrName) {
        const value = attr.childForFieldName('value');
        if (value) {
          // Remove quotes from attribute value
          const rawValue = value.text || '';
          return rawValue.replace(/^["']|["']$/g, '');
        }
      }
    }
    return null;
  }
}

// Register processor
function processHTMLNode(node, ancestors, extractor) {
  const htmlExtractor = new HTMLExtractor();
  htmlExtractor.processNode(node, ancestors);
}

TreeSitterExtractor.register('html', processHTMLNode);

module.exports = {
  HTMLExtractor,
  processHTMLNode
};
