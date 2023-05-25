module psi

import analyzer.psi.types

pub struct VarDefinition {
	PsiElementImpl
}

fn (_ &VarDefinition) expr() {}

pub fn (n &VarDefinition) identifier() ?PsiElement {
	return n.find_child_by_type(.identifier)
}

pub fn (n &VarDefinition) identifier_text_range() TextRange {
	identifier := n.identifier() or { return TextRange{} }
	return identifier.text_range()
}

pub fn (n &VarDefinition) name() string {
	identifier := n.identifier() or { return '' }
	return identifier.get_text()
}

pub fn (n &VarDefinition) declaration() ?&VarDeclaration {
	if parent := n.parent_nth(2) {
		if parent is VarDeclaration {
			return parent
		}
	}
	if parent := n.parent_nth(3) {
		if parent is VarDeclaration {
			return parent
		}
	}
	return none
}

pub fn (n &VarDefinition) get_type() types.Type {
	decl := n.declaration() or { return types.unknown_type }

	if init := decl.initializer_of(n) {
		if init is PsiTypedElement {
			return init.get_type()
		}
	}

	return types.unknown_type
}

pub fn (n &VarDefinition) mutability_modifiers() ?&MutabilityModifiers {
	if mut_expr := n.parent() {
		if mut_expr.node.type_name == .mutable_expression {
			modifiers := mut_expr.find_child_by_type(.mutability_modifiers)?
			if modifiers is MutabilityModifiers {
				return modifiers
			}
		}
	}

	return none
}

pub fn (n &VarDefinition) is_mutable() bool {
	mods := n.mutability_modifiers() or { return false }
	return mods.is_mutable()
}
