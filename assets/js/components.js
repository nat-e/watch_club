// Hooks for our UI components. Mirrors the structure of `components.css`:
// one entry per component file under `lib/shadcn/components/`,
// kept alphabetically sorted. The key is the name used in `phx-hook="..."`.
import { AlertDialogHook } from "../../lib/shadcn/components/alert_dialog";
import AvatarHook from "../../lib/shadcn/components/avatar";
import { CalendarHook } from "../../lib/shadcn/components/calendar";
import { CarouselHook } from "../../lib/shadcn/components/carousel";
import { ComboboxHook } from "../../lib/shadcn/components/combobox";
import { CommandHook } from "../../lib/shadcn/components/command";
import {
	ContextMenuHook,
	ContextMenuSubHook,
} from "../../lib/shadcn/components/context_menu";
import { DialogHook } from "../../lib/shadcn/components/dialog";
import { DrawerHook } from "../../lib/shadcn/components/drawer";
import {
	DropdownMenuHook,
	DropdownMenuSubHook,
} from "../../lib/shadcn/components/dropdown_menu";
import { HoverCardHook } from "../../lib/shadcn/components/hover_card";
import { InputOtpHook } from "../../lib/shadcn/components/input_otp";
import { MenubarHook } from "../../lib/shadcn/components/menubar";
import { NavigationMenuHook } from "../../lib/shadcn/components/navigation_menu";
import { PopoverHook } from "../../lib/shadcn/components/popover";
import { ResizableHook } from "../../lib/shadcn/components/resizable";
import { SelectHook } from "../../lib/shadcn/components/select";
import { SheetHook } from "../../lib/shadcn/components/sheet";
import { WCSidebarHook } from "../../lib/shadcn/components/sidebar";
import { SliderHook } from "../../lib/shadcn/components/slider";
import { TabsHook } from "../../lib/shadcn/components/tabs";
import { TooltipHook } from "../../lib/shadcn/components/tooltip";

export default {
	AlertDialogHook,
	AvatarHook,
	CalendarHook,
	CarouselHook,
	ComboboxHook,
	CommandHook,
	ContextMenuHook,
	ContextMenuSubHook,
	DialogHook,
	DrawerHook,
	DropdownMenuHook,
	DropdownMenuSubHook,
	HoverCardHook,
	InputOtpHook,
	MenubarHook,
	NavigationMenuHook,
	PopoverHook,
	ResizableHook,
	SelectHook,
	SheetHook,
	SliderHook,
	WCSidebarHook,
	TabsHook,
	TooltipHook,
};
