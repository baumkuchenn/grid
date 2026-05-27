String quoteMysqlIdentifier(String identifier) {
  return '`${identifier.replaceAll('`', '``')}`';
}
