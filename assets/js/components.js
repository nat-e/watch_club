// Hooks for our UI components. Mirrors the structure of `components.css`:
// one entry per component file under `lib/shadcn/components/`,
// kept alphabetically sorted. The key is the name used in `phx-hook="..."`.
import AvatarHook from "../../lib/shadcn/components/avatar";
import {
	DropdownMenuHook,
	DropdownMenuSubHook,
} from "../../lib/shadcn/components/dropdown_menu";
import { ModalHook } from "../../lib/shadcn/components/modal";
import { SelectHook } from "../../lib/shadcn/components/select";
import { WCSidebarHook } from "../../lib/shadcn/components/sidebar";

export default {
	AvatarHook,
	DropdownMenuHook,
	DropdownMenuSubHook,
	ModalHook,
	SelectHook,
	WCSidebarHook,
};
