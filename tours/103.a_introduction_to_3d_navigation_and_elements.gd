extends "../../addons/godot_tours/tour.gd"

func _build() -> void:
	bubble_set_title(gtr("103.a Introduction to 3D navigation and elements"))
	bubble_add_text([gtr("In this first tour, we will add the required elements for a 3D game to work and learn to navigate the 3D view."), "", gtr("Let's get right into it!")])
	bubble_move_and_anchor(interface.base_control, Bubble.At.CENTER)
	complete_step()

	bubble_set_title(gtr("The unfinished game scene"))
	bubble_add_text([gtr("I just opened the scene [b]unfinished_game.tscn[/b] for you."), "", gtr("This small game scene has a character, platforms, and a flag. Run the scene by clicking the \"play current scene\" button at the top right of the editor or pressing F6 on your keyboard."), "", gtr("You'll see a completely gray screen... Don't panic! It's what we expect. We'll explain why after you try!"), "", gtr("Press [b]F8[/b] or close the game window to stop the game.")])
	scene_open("unfinished_game.tscn")
	bubble_add_task_press_button(interface.run_bar_play_button)
	complete_step()

	bubble_set_title(gtr("The gray screen"))
	bubble_add_text([gtr("The screen was completely gray because the scene currently lacks a camera."), "", gtr("In the 3D world, like in the real world, we need something like a pair of eyes or a virtual camera to tell the computer where to look and what to display.")])
	complete_step()

	bubble_set_title(gtr("Add the camera node"))
	bubble_add_text([gtr("Let's add a Camera3D node to the scene."), "", gtr("Select the [b]Game[/b] node in the Scene dock and click the [b]Add Child Node[/b] button at the top left. You can also press [b]Ctrl+A[/b] on your keyboard (Cmd+A on macOS) to open the \"Add Node\" dialog. Search for the [b]Camera3D[/b] node and create it in the scene."), "", gtr("This will add it at the origin of the 3D game world, where the three world axes meet (the three thin red, green, and blue lines that cross)."), "", gtr("You can try running the scene now to see... something, at least! The camera is located at the world's origin, so it's not looking at the character."), "", gtr("The running game remains dark because there are no lights in the scene. We will add a light later. For now, let's learn to move the view and manipulate 3D nodes to place the camera behind the character.")])
	bubble_move_and_anchor(interface.canvas_item_editor_viewport, Bubble.At.TOP_LEFT)
	task(Add a Camera3D as a child of the Game node)
	complete_step()

	bubble_set_title(gtr("How to navigate the 3D view"))
	bubble_add_text([gtr("To move nodes where we need them in 3D, we often need to turn, pan, and zoom the view. Here's how you can do that in the 3D view:"), "", gtr("- To rotate the 3D view, hold the middle mouse button down and move the mouse."), gtr("- To pan the view and move around, hold the Shift key and middle mouse button down, then move the mouse."), gtr("- To zoom in and out, use the mouse wheel."), "", gtr("Try moving and turning the view to center the camera node in the viewport. You should see the camera icon in view and the wireframe of a tapered box extending from it. This box represents the direction the camera is looking.")])
	bubble_move_and_anchor(interface.base_control, Bubble.At.BOTTOM_RIGHT)
	# note: Don't bother implementing a task for steps like this one. We just let people explore.
	complete_step()

	bubble_set_title(gtr("Focus the camera node"))
	bubble_add_text([gtr("When you rotate the view, it rotates around an arbitrary point. This point is the last point of focus for the editor. By default, it's located at the center of the view."), "", gtr("You can quickly align the view to a node and make that node the focus point by selecting a node and pressing the [b]F[/b] key on your keyboard."), "", gtr("Ensure that the [b]Camera3D[/b] node is selected in the [b]Scene[/b] dock and press [b]F[/b] to focus the view on the camera. This will re-center the view on the camera."), "", gtr("Then, with the camera node focused, press the middle mouse button and drag to rotate the view around the camera.")])
	task(Focus the camera node (skip implementing if it's not simple))
	complete_step()

	bubble_set_title(gtr("Select the move mode"))
	bubble_add_text([gtr("To move a 3D object, as in 2D, you can use the [b]Move[/b] mode in the toolbar at the top. Select the Move mode to display the 3D position manipulator.")])
	task(Select the Move mode in the toolbar)
	complete_step()

	bubble_set_title(gtr("The 3D position manipulator"))
	bubble_add_text([gtr("The position manipulator has three axes you can click and drag to move the camera node on that axis. The red line corresponds to the X axis, the green line to the vertical Y axis, and the blue line to the Z axis."), "", "", gtr("You can also click and drag on the floating colored squares between axes to move the camera along the corresponding plane.")])
	short video clip(moving a node with the 3D position manipulator)
	picture(a colored square between two axes highlighted)
	complete_step()

	bubble_set_title(gtr("Move the camera"))
	bubble_add_text([gtr("Click and drag on the position manipulator axes and squares to move the camera node behind the character at a distance."), "", "", gtr("Use the navigation tricks you learned previously to move the view as needed:"), "", gtr("- Rotate the view with the middle mouse click."), gtr("- Pan the view with Shift + middle mouse click."), gtr("- Zoom in and out with the mouse wheel.")])
	picture(the camera node behind the player character in the viewport)
	complete_step()

	bubble_set_title(gtr("The camera direction"))
	bubble_add_text([gtr("By default, the camera faces away from the player character. We want to rotate it to look at the character."), "", gtr("The tapered box wireframe that expands from the camera icon in the viewport represents the direction in which the camera is looking."), "", "", gtr("We need this shape to extend towards the player character.")])
	picture(the camera icon and the wireframe box)
	complete_step()

	bubble_set_title(gtr("Select the Rotate mode"))
	bubble_add_text([gtr("Select the [b]Rotate[/b] mode in the toolbar to display the rotation manipulator. This manipulator has three circles representing the rotations you can perform: you can turn the selected node around the x, y, and z axes."), "", gtr("For example, clicking and dragging on the green circle will rotate the camera around the vertical axis, the y-axis.")])
	task(Select the Rotate mode in the toolbar)
	complete_step()

	bubble_set_title(gtr("Make the camera look at the player"))
	bubble_add_text([gtr("Using the Rotate mode, turn the camera to look roughly towards the player. Then, you can rotate it around the x and y axes, which are the red and green circles on the rotation manipulator."), "", gtr("Your camera should be roughly behind the player character and looking at it. Don't worry about getting it perfect; we'll adjust it shortly."), "", "", gtr("You can press [b]F6[/b] at any time to run the scene and see what the camera sees. Press [b]F8[/b] to stop the game."), "", gtr("Don't worry about the fact everything is dark; we'll address that in a moment.")])
	picture(the camera looking at the player character in the viewport)
	complete_step()

	bubble_set_title(gtr("The camera preview"))
	bubble_add_text([gtr("Running the scene to check the camera's view is cumbersome. Thankfully, we can use the camera preview to see what the camera sees in the editor."), "", gtr("You can toggle the camera preview by clicking the *preview* button at the top left of the viewport."), "", gtr("When you turn on the preview, you should see the player character in the camera view. You can also press [b]Ctrl+P[/b] on your keyboard (Cmd+P on macOS).")])
	highlight(camera preview button at the top left of the viewport)
	complete_step()

	bubble_set_title(gtr("Split the view in two"))
	bubble_add_text([gtr("Constantly switching between the camera preview and the free view is not convenient, is it? We can split the view into two to see both simultaneously."), "", gtr("To split the view, click on the view menu at the top of the toolbar and select one of the options. Go ahead and split the view into two viewports vertically. In the View menu, it's called 2 Viewports (Alt). You can also press Ctrl+Alt+2 on your keyboard (Cmd+Alt+2 on macOS).")])
	task(Split the view into two viewports)
	complete_step()

	bubble_set_title(gtr("Turn on the camera preview"))
	bubble_add_text([gtr("With two viewports and the Camera3D node still selected, click the Preview button in one of the views to preview the camera while you move and rotate the camera in the other view. Try it now."), "", gtr("Then, in the free view, move and rotate the camera using the Move and Rotate modes. Take your time to adjust the camera to your liking.")])
	task(Turn on the camera preview in one of the viewports (skip implementing if not simple))
	complete_step()

	bubble_set_title(gtr("Run the scene"))
	bubble_add_text([gtr("Press [b]F6[/b] to play the scene again. You will now see the player character and some of the background, except that it is all dark, with a gray sky. Press F8 to close the running game.")])
	complete_step()

	bubble_set_title(gtr("In 3D, you need light"))
	bubble_add_text([gtr("A 3D game is composed of 3D geometry shaded by [b]light[/b] and [b]materials[/b]."), "", gtr("Our scene has 3D geometry and materials predefined, but currently, it does not have light. "), "", gtr("It looks fine in the viewport because Godot provides default lighting to help us prototype scenes until we add our own lights."), "", gtr("We can turn off the default lighting by clicking the two icons in the toolbar. They toggle the preview sunlight and the preview environment. Turn off the two icons highlighted in the toolbar at the top.")])
	task(Turn off the preview sunlight and sky)
	complete_step()

	bubble_set_title(gtr("The most common light types"))
	bubble_add_text([gtr("Your 3D viewport in the editor should now display the scene as you see it in the game, very dark. Once we add lights to a 3D scene, Godot automatically turns off the default lights. For now, turning them off yourself gives you a faithful preview of what the game will look like."), "", gtr("Godot has three nodes representing different types of lights: SpotLight3D, OmniLight3D, and DirectionalLight3D."), "", gtr("The OmniLight3D and SpotLight3D nodes simulate light bulbs and torchlights, among other similar kinds of lights."), "", gtr("The DirectionalLight3D node simulates the sun. It applies uniform directional lighting to the entire scene.")])
	complete_step()

	bubble_set_title(gtr("Add a directional light"))
	bubble_add_text([gtr("As our scene is an exterior, we will add a DirectionalLight3D node to simulate sunlight. Select the Game node in the Scene dock and add a DirectionalLight3D node as a child of it.")])
	bubble(top left of the viewport)
	task(Add a DirectionalLight3D node to the scene)
	complete_step()

	bubble_set_title(gtr("The directional light"))
	bubble_add_text([gtr("At first, the light is aligned with the ground plane and illuminates the character from the front but not the floor."), "", gtr("We'll rotate the light to angle it down and light up the character and the ground."), "", gtr("First, focus the directional light by selecting it and pressing the [b]F[/b] key. This will center the view on the light.")])
	task(Focus the directional light (skip implementing if not simple))
	complete_step()

	bubble_set_title(gtr("Activate the Rotate mode"))
	bubble_add_text([gtr("We can use the [b]Rotate[/b] mode in the toolbar to rotate the light. Click the icon or press [b]E[/b] on your keyboard to activate the Rotate mode.")])
	task(Select the Rotate mode in the toolbar)
	complete_step()

	bubble_set_title(gtr("The rotation manipulator"))
	bubble_add_text([gtr("Upon selecting the Rotate mode, you see the rotation manipulator, which has three circles representing the rotations you can perform: you can turn the selected node around the x, y, and z axes."), "", gtr("Click and drag on any of these three circles to rotate the light around the corresponding axis."), "", "", gtr("Clicking and dragging anywhere else in the viewport will rotate the light parallel to the view's forward axis.")])
	short video clip(rotating a node with the three axes of the rotation manipulator)
	complete_step()

	bubble_set_title(gtr("Rotate the directional light"))
	bubble_add_text([gtr("The light direction is represented by the white wire arrow that's aligned with the ground plane by default."), "", "", gtr("Rotate the light by clicking and dragging on the red circle to rotate it around the x-axis and angle it down."), "", "", gtr("If you still have the two viewports active, you should see the character and the ground get lit uniformly from above.")])
	task(Rotate the light to angle it down (rotation.x should be any negative value))
	picture(of the directional light arrow)
	video clip(rotating the directional light to angle it down)
	complete_step()

	bubble_set_title(gtr("To shade or not to shade"))
	bubble_add_text([gtr("Notice how the player character does not cast a shadow. By default, lights in 3D games do not cast shadows for performance reasons."), "", gtr("We can optionally activate shadows on each light to make this light cast shadows in the game. "), "", gtr("As more lights cast shadows, the lighting becomes more realistic, but the game becomes more performance-intensive."), "", gtr("It's common to activate shadows for at least the directional light.")])
	complete_step()

	bubble_set_title(gtr("Enable shadows on the directional light"))
	bubble_add_text([gtr("Make sure you have the DirectionalLight3D node selected. Then, in the Inspector, expand the Shadow category and turn on the Enable property. Shadows will appear behind the character and the flag."), "", gtr("There are a bunch of settings to tweak the quality and range of the shadow, but we'll learn all about that later in the course."), "", gtr("Run the scene again with [b]F6[/b] to see that the character is lit and casts a shadow on the ground. The game should look better now.")])
	task(Enable shadows on the DirectionalLight3D node)
	complete_step()

	bubble_set_title(gtr("The world environment"))
	bubble_add_text([gtr("While we added a directional light, we still have lots of shaded areas in our level, and the background is all gray."), "", gtr("To change the background, we can use a WorldEnvironment node. This node takes an Environment resource and allows us to define a sky in the game. It also controls post-processing effects built into Godot, like fog, contrast, and more."), "", gtr("We won't be creating an environment from scratch now; we'll learn that later in the course. For now, we'll use one we've prepared for you.")])
	complete_step()

	bubble_set_title(gtr("Add a WorldEnvironment node"))
	bubble_add_text([gtr("First, select the Game node in the Scene dock and add a new WorldEnvironment node as a child of it. This node alone does nothing; it needs an Environment resource to work. We'll add it in the next step.")])
	task(Create a WorldEnvironment node)
	complete_step()

	bubble_set_title(gtr("Add the environment resource"))
	bubble_add_text([gtr("With the WorldEnvironment node selected, click and drag the [b]world_environment.tres[/b] file from the FileSystem dock onto the Environment property in the Inspector."), "", gtr("It's an environment we've prepared for you. It has a soft purple sky and uses the fog effect to give the platforms depth.")])
	complete_step()

	bubble_set_title(gtr("The ambient lighting"))
	bubble_add_text([gtr("The sky brightens the scene and gives it a more appealing look. It uses a simple, uniform light that comes from all directions, called [b]ambient lighting[/b]. It's a very efficient and performance-friendly way to light a scene. It also works great for stylized visuals, like the style we're going for in this course.")])
	complete_step()

	bubble_set_title(gtr("Expand the ambient light"))
	bubble_add_text([gtr("Let's see how it works in the [b]Inspector[/b] dock. With the WorldEnvironment node selected, click the Environment resource to expand its properties. Then, expand the [b]Ambient Light[/b] category."), "", gtr("It reveals four properties: Source, Color, Sky Contribution, and Energy."), "", gtr("The source of the ambient light is the purple sky, and it contributes to the scene's lighting. The sky colors are mixed with the Color property based on the Sky Contribution value. The Energy property controls the intensity of the ambient light.")])
	complete_step()

	bubble_set_title(gtr("Tweak the ambient light"))
	bubble_add_text([gtr("Take a moment to play with these properties and see how they affect the scene. The Color property is particularly fun to tweak! It tints all the platforms and the character with the color you choose."), "", gtr("Note that it won't do anything if Sky Contribution is set to 1.0. You need to lower the sky's contribution to see the effect.")])
	complete_step()
