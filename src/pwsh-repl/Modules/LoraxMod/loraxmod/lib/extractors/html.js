// HTML extractor
// Supports: elements, scripts, styles

const { TreeSitterExtractor } = require('./base-extractor');

class HTMLExtractor extends TreeSitterExtractor {
  constructor() {
    super('html');
  }

  processNode(node, ancestors) {
    switch (node.type) {
      case 'element':
        // HTML elements like <div>, <button>, etc.
        const startTag = node.children.find(c => c.type === 'start_tag');
        if (startTag) {
          const tagNameNode = startTag.children.find(c => c.type === 'tag_name');
          if (tagNameNode) {
            const elementName = tagNameNode.text;
            // Extract id or class if available
            let identifier = elementName;
            const attributes = startTag.children.filter(c => c.type === 'attribute');
            for (const attr of attributes) {
              const attrNameNode = attr.children.find(c => c.type === 'attribute_name');
              const attrValueNode = attr.children.find(c => c.type === 'quoted_attribute_value');
              if (attrNameNode && attrValueNode) {
                if (attrNameNode.text === 'id') {
                  identifier = `${elementName}#${attrValueNode.text.replace(/["']/g, '')}`;
                  break;
                } else if (attrNameNode.text === 'class') {
                  const className = attrValueNode.text.replace(/["']/g, '').split(/\s+/)[0];
                  if (className) {
                    identifier = `${elementName}.${className}`;
                  }
                }
              }
            }
            this.addSegment(node, 'element', identifier, ancestors);
          }
        }
        break;

      case 'script_element':
        // <script> tags
        this.addSegment(node, 'script', 'script', ancestors);
        break;

      case 'style_element':
        // <style> tags
        this.addSegment(node, 'style', 'style', ancestors);
        break;
    }
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
