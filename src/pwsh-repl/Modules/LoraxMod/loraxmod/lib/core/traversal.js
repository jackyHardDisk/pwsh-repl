// Tree-sitter AST traversal utilities
// Extracted from vibe_tools for loraxMod

/**
 * Traverse AST with ancestor tracking
 * This is the key trick that enables context-aware parsing:
 * - Preserves parent class names for methods
 * - Detects top-level vs nested scope
 * - Identifies containing contexts for symbols
 *
 * @param {TreeSitter.SyntaxNode} node - Current AST node
 * @param {TreeSitter.SyntaxNode[]} ancestors - Array of ancestor nodes
 * @param {Function} visitor - Callback function(node, ancestors)
 */
function traverseWithAncestors(node, ancestors, visitor) {
  // Call visitor with current node and ancestors
  visitor(node, ancestors);

  // Traverse children with updated ancestor chain
  const childCount = node.childCount;
  for (let i = 0; i < childCount; i++) {
    const childNode = node.child(i);
    if (childNode) {
      const newAncestors = [...ancestors, node]; // Add current node to ancestor chain
      traverseWithAncestors(childNode, newAncestors, visitor);
    }
  }
}

/**
 * Find ancestor node of specific type
 * @param {TreeSitter.SyntaxNode[]} ancestors - Array of ancestor nodes
 * @param {string|string[]} types - Node type(s) to search for
 * @returns {TreeSitter.SyntaxNode|null} First matching ancestor or null
 */
function findAncestor(ancestors, types) {
  const typeArray = Array.isArray(types) ? types : [types];

  for (let i = ancestors.length - 1; i >= 0; i--) {
    if (typeArray.includes(ancestors[i].type)) {
      return ancestors[i];
    }
  }

  return null;
}

/**
 * Check if node is at top level (not inside function/method)
 * @param {TreeSitter.SyntaxNode[]} ancestors - Array of ancestor nodes
 * @param {string} language - Language identifier
 * @returns {boolean} True if node is at top level
 */
function isTopLevel(ancestors, language) {
  const containerTypes = {
    javascript: ['function_declaration', 'arrow_function', 'function_expression'],
    python: ['function_definition', 'class_definition'],
    bash: ['function_definition'],
    powershell: ['function_statement', 'function_definition'],
    r: ['function_definition'],
    csharp: ['method_declaration', 'function_declaration', 'local_function_statement']
  };

  const containers = containerTypes[language] || [];
  return !ancestors.some(ancestor => containers.includes(ancestor.type));
}

/**
 * Get parent class name from ancestors
 * @param {TreeSitter.SyntaxNode[]} ancestors - Array of ancestor nodes
 * @param {string} language - Language identifier
 * @returns {string|null} Parent class name or null
 */
function getParentClassName(ancestors, language) {
  const classTypes = {
    javascript: ['class_declaration', 'class_expression'],
    python: ['class_definition'],
    bash: [],
    powershell: ['class_statement', 'class_definition'],
    r: [],
    csharp: ['class_declaration']
  };

  const types = classTypes[language] || [];

  for (let i = ancestors.length - 1; i >= 0; i--) {
    const ancestor = ancestors[i];
    if (types.includes(ancestor.type)) {
      const classNameNode = ancestor.childForFieldName('name');
      if (classNameNode) {
        return classNameNode.text;
      }
    }
  }

  return null;
}

module.exports = {
  traverseWithAncestors,
  findAncestor,
  isTopLevel,
  getParentClassName
};
