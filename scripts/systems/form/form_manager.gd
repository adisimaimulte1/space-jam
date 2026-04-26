extends Node

signal form_changed(new_form: int)

enum FormState {
	ORIGIN,
	ALTER
}

var current_form: int = FormState.ORIGIN


func set_form(new_form: int) -> void:
	if current_form == new_form:
		return

	current_form = new_form
	form_changed.emit(current_form)


func is_origin() -> bool:
	return current_form == FormState.ORIGIN


func is_alter() -> bool:
	return current_form == FormState.ALTER
