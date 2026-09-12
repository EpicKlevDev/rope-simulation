extends Node

var new_position: Vector2
var speed: Vector2 = Vector2.ZERO
var gravity: float = 980
var time

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	speed += Vector2(0, gravity) * delta
	new_position += speed * delta
	self.position.y = new_position.y
	print("Position: ", new_position, " Speed: ", speed)
	pass
