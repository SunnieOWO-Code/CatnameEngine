package funkin.editors.hud;

import flixel.math.FlxPoint;
import haxe.Json;
import haxe.io.Path;
import lime.ui.FileDialog;
#if lime_funkin
import lime.ui.FileDialogFilter;
#end
import sys.FileSystem;
import sys.io.File;
import funkin.editors.ui.*;

typedef HudElementData = {
	var id:String;
	var name:String;
	var x:Float;
	var y:Float;
	var scaleX:Float;
	var scaleY:Float;
	var alpha:Float;
	var visible:Bool;
	var image:String;
	var type:String;
	var text:String;
}

typedef HudLayoutData = {
	var elements:Array<HudElementData>;
}

class HudEditor extends UIState {
	public static var instance(get, null):HudEditor;
	private static inline function get_instance():HudEditor {
		return FlxG.state is HudEditor ? cast FlxG.state : null;
	}

	public static inline var LAYOUT_PATH:String = "assets/data/hud/editor-layout.json";

	public var hudRoot:FlxSprite;
	public var layerGroup:FlxTypedGroup<HudElementSprite> = new FlxTypedGroup<HudElementSprite>();
	public var elements:Array<HudElementSprite> = [];
	public var selected:HudElementSprite = null;

	public var panel:UISliceSprite;
	public var titleText:UIText;
	public var addImageBtn:UIButton;
	public var addTextBtn:UIButton;
	public var saveBtn:UIButton;
	public var resetBtn:UIButton;

	public var xStepper:UINumericStepper;
	public var yStepper:UINumericStepper;
	public var scaleXStepper:UINumericStepper;
	public var scaleYStepper:UINumericStepper;
	public var alphaStepper:UINumericStepper;

	public override function create() {
		super.create();
		WindowUtils.suffix = " (HUD Editor)";

		hudRoot = new FlxSprite();
		hudRoot.makeGraphic(1, 1, 0xFF111827);
		hudRoot.scale.set(FlxG.width, FlxG.height);
		hudRoot.updateHitbox();
		hudRoot.scrollFactor.set();
		add(hudRoot);
		add(layerGroup);

		buildToolbar();
		loadLayout();
	}

	private function buildToolbar() {
		panel = new UISliceSprite(16, 16, 566, 180, 'editors/ui/inputbox');
		panel.alpha = 0.92;
		add(panel);

		titleText = new UIText(28, 26, 220, "HUD editor", 22);
		titleText.alignment = LEFT;
		panel.members.push(titleText);

		addImageBtn = new UIButton(26, 56, "Add image", () -> openImagePicker(), 120, 32);
		addTextBtn = new UIButton(26 + 120 + 16, 56, "Add text", () -> addTextElement(), 120, 32);
		saveBtn = new UIButton(26, 96, "Save", () -> saveLayout(), 120, 32);
		resetBtn = new UIButton(26 + 120 + 16, 96, "Reset", () -> loadDefaults(), 120, 32);

		panel.members.push(addImageBtn);
		panel.members.push(addTextBtn);
		panel.members.push(saveBtn);
		panel.members.push(resetBtn);

		xStepper = new UINumericStepper(260, 56, 0, 1, 2, null, null, 120);
		yStepper = new UINumericStepper(260 + 120 + 18, 56, 0, 1, 2, null, null, 120);
		scaleXStepper = new UINumericStepper(260, 96, 1, 0.01, 2, 0, null, 120);
		scaleYStepper = new UINumericStepper(260 + 120 + 18, 96, 1, 0.01, 2, 0, null, 120);
		alphaStepper = new UINumericStepper(260, 136, 1, 0.01, 2, 0, 1, 120);

		xStepper.onChange = (_) -> updateSelectedPosition();
		yStepper.onChange = (_) -> updateSelectedPosition();
		scaleXStepper.onChange = (_) -> updateSelectedScale();
		scaleYStepper.onChange = (_) -> updateSelectedScale();
		alphaStepper.onChange = (_) -> updateSelectedAlpha();

		panel.members.push(xStepper);
		panel.members.push(yStepper);
		panel.members.push(scaleXStepper);
		panel.members.push(scaleYStepper);
		panel.members.push(alphaStepper);
	}

	private function loadLayout() {
		var layoutPath = getLayoutPath();
		if (FileSystem.exists(layoutPath)) {
			try {
				var raw:String = File.getContent(layoutPath);
				var data:HudLayoutData = Json.parse(raw);
				if (data != null && data.elements != null && data.elements.length > 0) {
					for (element in data.elements)
						addElement(element, false);
					if (elements.length > 0)
						selectElement(elements[0]);
					return;
				}
			} catch (e:Dynamic) {}
		}
		loadDefaults();
	}

	private function loadDefaults() {
		for (sprite in elements) {
			sprite.destroy();
		}
		elements = [];
		hudRoot.clear();
		hudRoot.makeGraphic(1, 1, 0xFF111827);
		hudRoot.scale.set(FlxG.width, FlxG.height);
		hudRoot.updateHitbox();
		hudRoot.scrollFactor.set();
		hudRoot.visible = true;
		layerGroup.clear();

		var def:Array<HudElementData> = [
			{id: "healthBarBG", name: "Health bar BG", x: 0, y: FlxG.height * 0.9, scaleX: 1, scaleY: 1, alpha: 1, visible: true, image: "game/healthBar", type: "sprite", text: null},
			{id: "healthBar", name: "Health bar fill", x: 20, y: FlxG.height * 0.9 + 4, scaleX: 1, scaleY: 1, alpha: 1, visible: true, image: "game/healthBar", type: "sprite", text: null},
			{id: "iconP1", name: "Player icon", x: 90, y: FlxG.height * 0.88, scaleX: 1, scaleY: 1, alpha: 1, visible: true, image: "icons/face", type: "sprite", text: null},
			{id: "iconP2", name: "Opponent icon", x: FlxG.width - 180, y: FlxG.height * 0.88, scaleX: 1, scaleY: 1, alpha: 1, visible: true, image: "icons/dad", type: "sprite", text: null},
			{id: "scoreTxt", name: "Score", x: 230, y: FlxG.height * 0.9 + 22, scaleX: 1, scaleY: 1, alpha: 1, visible: true, image: null, type: "text", text: "Score: 0"},
			{id: "missesTxt", name: "Misses", x: 230, y: FlxG.height * 0.9 + 48, scaleX: 1, scaleY: 1, alpha: 1, visible: true, image: null, type: "text", text: "Misses: 0"},
			{id: "accuracyTxt", name: "Accuracy", x: 230, y: FlxG.height * 0.9 + 72, scaleX: 1, scaleY: 1, alpha: 1, visible: true, image: null, type: "text", text: "Accuracy: 100%"}
		];

		for (item in def)
			addElement(item, false);
		if (elements.length > 0)
			selectElement(elements[0]);
	}

	private function addTextElement() {
		var data:HudElementData = {
			id: "customText_" + Std.int(Math.random() * 10000),
			name: "Custom text",
			x: 120,
			y: 120,
			scaleX: 1,
			scaleY: 1,
			alpha: 1,
			visible: true,
			image: null,
			type: "text",
			text: "NEW TEXT"
		};
		addElement(data, true);
	}

	private function openImagePicker() {
		#if lime_funkin
		FileDialog.openFile(FlxG.stage.window, "Open image", (names:Array<String>, filter:FileDialogFilter) -> {
			if (names == null || names.length == 0) return;
			var filePath:String = names[0];
			if (filePath == null || filePath.length == 0) return;
			addImageFromPath(filePath);
		}, [new FileDialogFilter("Images", "png;jpg;jpeg;gif;bmp;webp")]);
		#else
		var fileDialog = new FileDialog();
		fileDialog.onSelect.add(function(path:String) {
			if (path != null && path.length > 0)
				addImageFromPath(path);
		});
		fileDialog.browse(OPEN, "png");
		#end
	}

	private function addImageFromPath(filePath:String) {
		var normalized:String = Path.normalize(filePath).replace("\\", "/");
		var relative:String = normalized;
		if (normalized.indexOf("assets/") != -1)
			relative = normalized.substring(normalized.indexOf("assets/") + "assets/".length);
		if (relative.startsWith("images/"))
			relative = relative.substring("images/".length);
		relative = relative.replace(".png", "").replace(".jpg", "").replace(".jpeg", "").replace(".gif", "").replace(".bmp", "").replace(".webp", "");

		var data:HudElementData = {
			id: "customSprite_" + Std.int(Math.random() * 10000),
			name: "Custom sprite",
			x: 160,
			y: 160,
			scaleX: 1,
			scaleY: 1,
			alpha: 1,
			visible: true,
			image: relative,
			type: "sprite",
			text: null
		};
		addElement(data, true);
	}

	private function addElement(data:HudElementData, selectAfter:Bool) {
		var element = new HudElementSprite(data);
		elements.push(element);
		layerGroup.add(element);
		if (selectAfter)
			selectElement(element);
	}

	public function selectElement(element:HudElementSprite) {
		if (element == null) return;
		selected = element;
		for (sprite in elements)
			sprite.selected = sprite == element;
		updateSelectedFields();
	}

	private function updateSelectedFields() {
		if (selected == null) {
			xStepper.value = 0;
			yStepper.value = 0;
			scaleXStepper.value = 1;
			scaleYStepper.value = 1;
			alphaStepper.value = 1;
			return;
		}

		xStepper.value = selected.data.x;
		yStepper.value = selected.data.y;
		scaleXStepper.value = selected.data.scaleX;
		scaleYStepper.value = selected.data.scaleY;
		alphaStepper.value = selected.data.alpha;
	}

	private function updateSelectedPosition() {
		if (selected == null) return;
		selected.x = xStepper.value;
		selected.y = yStepper.value;
		selected.data.x = xStepper.value;
		selected.data.y = yStepper.value;
	}

	private function updateSelectedScale() {
		if (selected == null) return;
		selected.scale.set(scaleXStepper.value, scaleYStepper.value);
		selected.data.scaleX = scaleXStepper.value;
		selected.data.scaleY = scaleYStepper.value;
	}

	private function updateSelectedAlpha() {
		if (selected == null) return;
		selected.alpha = alphaStepper.value;
		selected.data.alpha = alphaStepper.value;
	}

	private function saveLayout() {
		var layoutPath = getLayoutPath();
		var dir = Path.directory(layoutPath);
		if (!FileSystem.exists(dir))
			FileSystem.createDirectory(dir);

		var payload:HudLayoutData = {
			elements: [for (sprite in elements) {
				id: sprite.data.id,
				name: sprite.data.name,
				x: sprite.data.x,
				y: sprite.data.y,
				scaleX: sprite.data.scaleX,
				scaleY: sprite.data.scaleY,
				alpha: sprite.data.alpha,
				visible: sprite.data.visible,
				image: sprite.data.image,
				type: sprite.data.type,
				text: sprite.data.text
			}]
		};

		File.saveContent(layoutPath, Json.stringify(payload, null, "\t"));
	}

	private function getLayoutPath():String {
		return Path.normalize(Path.join([Sys.getCwd(), LAYOUT_PATH]));
	}

	public override function update(elapsed:Float) {
		super.update(elapsed);
		if (selected != null && FlxG.mouse.justPressed && !panel.overlapsPoint(FlxG.mouse.getScreenPosition())) {
			selected.data.x = selected.x;
			selected.data.y = selected.y;
			updateSelectedFields();
		}
	}
}

class HudElementSprite extends UISprite {
	public var data:HudElementData;
	public var label:UIText;
	public var selected:Bool = false;

	public function new(data:HudElementData) {
		super();
		this.data = data;
		this.selected = false;
		this.exists = true;
		this.alpha = Math.max(0, Math.min(1, data.alpha));
		this.visible = data.visible;
		this.scrollFactor.set();
		this.cursor = MOVE;

		if (data.type == "text") {
			label = new UIText(0, 0, 260, data.text != null ? data.text : data.name, 18);
			label.borderStyle = OUTLINE;
			label.borderColor = 0xFF000000;
			label.borderSize = 1;
			this.members.push(label);
		} else {
			if (data.image != null && data.image.length > 0) {
				var spritePath:String = Paths.image(data.image);
				if (Assets.exists(spritePath))
					loadGraphic(spritePath);
				else
					makeGraphic(128, 32, 0xFF3B82F6);
			} else {
				makeGraphic(128, 32, 0xFF3B82F6);
			}
		}

		setPosition(data.x, data.y);
		scale.set(data.scaleX, data.scaleY);
		updateHitbox();
		antialiasing = true;
	}

	public override function update(elapsed:Float) {
		super.update(elapsed);
		if (label != null)
			label.follow(this, 0, 0);
	}

	public override function onHovered() {
		super.onHovered();
		if (FlxG.mouse.justPressed)
			HudEditor.instance.selectElement(this);
	}
}
