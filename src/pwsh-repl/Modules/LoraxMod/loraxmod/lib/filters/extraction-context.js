// Extraction context filtering
// Extracted from vibe_tools for loraxMod

/**
 * Check if segment matches extraction context filters
 * @param {Object} segment - Segment to check
 * @param {Object} extractionContext - Context with filters
 * @returns {boolean} True if segment matches
 */
function matchesExtractionContext(segment, extractionContext) {
  if (!extractionContext) return true;

  if (extractionContext.Elements && extractionContext.Elements.length > 0) {
    if (!extractionContext.Elements.includes(segment.type)) return false;
  }

  if (extractionContext.Exclusions && extractionContext.Exclusions.includes(segment.type)) {
    return false;
  }

  if (extractionContext.Filters) {
    if (extractionContext.Filters.FunctionName) {
      const targetName = extractionContext.Filters.FunctionName;
      if (segment.type === 'method') {
        const methodName = segment.name.includes('.') ? segment.name.split('.').pop() : segment.name;
        if (methodName !== targetName && segment.name !== targetName) return false;
      } else {
        if (segment.name !== targetName) return false;
      }
    }

    if (extractionContext.Filters.ClassName && segment.name !== extractionContext.Filters.ClassName) {
      return false;
    }

    if (extractionContext.Filters.Extends && segment.extends !== extractionContext.Filters.Extends) {
      return false;
    }
  }

  return true;
}

/**
 * Apply extraction context filtering to segments
 * @param {Array} segments - Array of segments
 * @param {Object} extractionContext - Context with filters
 * @param {string} code - Original code (for reference)
 * @returns {Array} Filtered segments
 */
function applyExtractionContext(segments, extractionContext, code) {
  if (!extractionContext) return segments;

  let filtered = segments.filter(segment => matchesExtractionContext(segment, extractionContext));

  if (extractionContext.ScopeFilter === 'top-level') {
    filtered = filtered.filter(segment => {
      if (segment.type === 'method') return false;
      return true;
    });
  }

  return filtered;
}

module.exports = {
  matchesExtractionContext,
  applyExtractionContext
};
