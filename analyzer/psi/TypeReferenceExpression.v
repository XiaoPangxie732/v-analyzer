module psi

import analyzer.psi.types

pub struct TypeReferenceExpression {
	PsiElementImpl
}

fn (_ &TypeReferenceExpression) stub() {}

// marker method for Expression
fn (_ &TypeReferenceExpression) expr() {}

pub fn (r TypeReferenceExpression) identifier() ?PsiElement {
	return r.first_child()
}

pub fn (r &TypeReferenceExpression) identifier_text_range() TextRange {
	if r.stub_id != non_stubbed_element {
		if stub := r.stubs_list.get_stub(r.stub_id) {
			return stub.text_range
		}
	}

	identifier := r.identifier() or { return TextRange{} }
	return identifier.text_range()
}

pub fn (r TypeReferenceExpression) name() string {
	if r.stub_id != non_stubbed_element {
		if stub := r.stubs_list.get_stub(r.stub_id) {
			return stub.name
		}
	}

	identifier := r.identifier() or { return '' }
	return identifier.get_text()
}

pub fn (r TypeReferenceExpression) qualifier() ?PsiElement {
	parent := r.parent() or { return none }

	if parent is TypeSelectorExpression {
		left := parent.left()
		if left.is_equal(r) {
			return none
		}

		return left
	}

	return none
}

pub fn (r TypeReferenceExpression) reference() PsiReference {
	if parent := r.parent() {
		if parent is ValueAttribute {
			return new_attribute_reference(r.containing_file, r)
		}
	}

	return new_reference(r.containing_file, r, true)
}

pub fn (r TypeReferenceExpression) resolve() ?PsiElement {
	return r.reference().resolve()
}

pub fn (r TypeReferenceExpression) get_type() types.Type {
	element := r.resolve() or { return types.unknown_type }

	if element is PsiTypedElement {
		return element.get_type()
	}

	return types.unknown_type
}
