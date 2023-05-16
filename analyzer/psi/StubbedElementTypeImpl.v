module psi

pub struct StubbedElementType {
	name       string
	debug_name string
}

fn (s &StubbedElementType) external_id() string {
	return 'vlang.${s.debug_name}'
}

pub fn (s &StubbedElementType) index_stub(stub &StubBase, mut sink IndexSink) {
	if stub.stub_type == .function_declaration {
		name := stub.name()
		sink.occurrence(StubIndexKey.functions, name)
	}

	if stub.stub_type == .method_declaration {
		receiver := stub.receiver()
		sink.occurrence(StubIndexKey.methods, receiver)
	}

	if stub.stub_type == .struct_declaration {
		name := stub.name()
		sink.occurrence(StubIndexKey.structs, name)
	}

	if stub.stub_type == .constant_declaration {
		name := stub.name()
		sink.occurrence(StubIndexKey.constants, name)
	}

	if stub.stub_type == .type_alias_declaration {
		name := stub.name()
		sink.occurrence(StubIndexKey.type_aliases, name)
	}
}

pub fn (s &StubbedElementType) create_psi(stub &StubBase) ?PsiElement {
	stub_type := stub.stub_type()
	base_psi := new_psi_node_from_stub(stub.id, stub.stub_list)

	if stub_type == .function_declaration || stub_type == .method_declaration {
		return FunctionOrMethodDeclaration{
			PsiElementImpl: base_psi
		}
	}
	if stub_type == .receiver {
		return Receiver{
			PsiElementImpl: base_psi
		}
	}
	if stub_type == .signature {
		return Signature{
			PsiElementImpl: base_psi
		}
	}
	if stub_type == .struct_declaration {
		return StructDeclaration{
			PsiElementImpl: base_psi
		}
	}
	if stub_type == .field_declaration {
		return FieldDeclaration{
			PsiElementImpl: base_psi
		}
	}
	if stub_type == .constant_declaration {
		return ConstantDefinition{
			PsiElementImpl: base_psi
		}
	}
	if stub_type == .type_alias_declaration {
		return TypeAliasDeclaration{
			PsiElementImpl: base_psi
		}
	}
	if stub_type == .plain_type {
		return PlainType{
			PsiElementImpl: base_psi
		}
	}
	return base_psi
}

pub fn (s &StubbedElementType) get_receiver_type(psi FunctionOrMethodDeclaration) string {
	receiver := psi.receiver() or { return '' }
	typ := receiver.type_element() or { return '' }
	return typ.get_text()
}

pub fn (s &StubbedElementType) create_stub(psi PsiElement, parent_stub &StubElement) ?&StubBase {
	if psi is FunctionOrMethodDeclaration {
		text_range := if identifier := psi.identifier() {
			identifier.text_range()
		} else {
			psi.text_range()
		}
		comment := psi.doc_comment()

		receiver_type := s.get_receiver_type(psi)
		is_method := receiver_type != ''
		stub_type := if is_method {
			StubType.method_declaration
		} else {
			StubType.function_declaration
		}
		return new_stub_base(parent_stub, stub_type, psi.name(), text_range,
			text: psi.get_text()
			comment: comment
			receiver: receiver_type
		)
	}

	if psi is Receiver {
		text_range := if identifier := psi.identifier() {
			identifier.text_range()
		} else {
			psi.text_range()
		}
		return new_stub_base(parent_stub, .receiver, psi.name(), text_range,
			text: psi.get_text()
		)
	}

	if psi is Signature {
		return new_stub_base(parent_stub, .signature, '', psi.text_range(),
			text: psi.get_text()
		)
	}

	if psi is StructDeclaration {
		text_range := if identifier := psi.identifier() {
			identifier.text_range()
		} else {
			psi.text_range()
		}
		comment := psi.doc_comment()
		return new_stub_base(parent_stub, .struct_declaration, psi.name(), text_range,

			text: psi.get_text()
			comment: comment
		)
	}

	if psi is FieldDeclaration {
		text_range := if identifier := psi.identifier() {
			identifier.text_range()
		} else {
			psi.text_range()
		}
		comment := psi.doc_comment()
		return new_stub_base(parent_stub, .field_declaration, psi.name(), text_range,

			text: psi.get_text()
			comment: comment
		)
	}

	if psi is ConstantDefinition {
		text_range := if identifier := psi.identifier() {
			identifier.text_range()
		} else {
			psi.text_range()
		}
		comment := psi.doc_comment()
		return new_stub_base(parent_stub, .constant_declaration, psi.name(), text_range,

			text: psi.get_text()
			comment: comment
		)
	}

	if psi is TypeAliasDeclaration {
		text_range := if identifier := psi.identifier() {
			identifier.text_range()
		} else {
			psi.text_range()
		}
		comment := psi.doc_comment()
		return new_stub_base(parent_stub, .type_alias_declaration, psi.name(), text_range,

			text: psi.get_text()
			comment: comment
		)
	}

	if psi is PlainType {
		return new_stub_base(parent_stub, .plain_type, '', psi.text_range(),
			text: psi.get_text()
		)
	}

	return none
}

pub fn (s &StubbedElementType) serialize(stub StubElement, mut stream StubOutputStream) {
	stub_type := stub.stub_type()
	if stub_type == .function_declaration {
		stream.write_u8(u8(stub_type))
		stream.write_name(stub.name())
	}

	if stub_type == .struct_declaration {
		stream.write_u8(u8(stub_type))
		stream.write_name(stub.name())
	}

	if stub_type == .field_declaration {
		stream.write_u8(u8(stub_type))
		stream.write_name(stub.name())
	}

	if stub_type == .constant_declaration {
		stream.write_u8(u8(stub_type))
		stream.write_name(stub.name())
	}

	if stub_type == .plain_type {
		stream.write_u8(u8(stub_type))
		stream.write_name(stub.name())
	}
}

pub fn (s &StubbedElementType) deserialize(stream StubInputStream, parent_stub &StubElement) ?&StubElement {
	stub_type := unsafe { StubType(stream.read_u8()) }
	match stub_type {
		.root {}
		.function_declaration {
			return new_stub_base(parent_stub, .function_declaration, stream.read_name(),
				TextRange{},
				text: stream.read_name()
			)
		}
		.constant_declaration {
			return new_stub_base(parent_stub, .constant_declaration, stream.read_name(),
				TextRange{},
				text: stream.read_name()
			)
		}
		.struct_declaration {
			return new_stub_base(parent_stub, .struct_declaration, stream.read_name(),
				TextRange{},
				text: stream.read_name()
			)
		}
		.field_declaration {
			return new_stub_base(parent_stub, .field_declaration, stream.read_name(),
				TextRange{},
				text: stream.read_name()
			)
		}
		.plain_type {
			return new_stub_base(parent_stub, .plain_type, stream.read_name(), TextRange{},

				text: stream.read_name()
			)
		}
		.signature {}
		.type_alias_declaration {}
		.method_declaration {}
		.receiver {}
	}

	return none
}
