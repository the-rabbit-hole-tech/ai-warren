import { rel } from "@/lib/api";

export const folder = rel.split("/")[0] ?? "";
// A folder's landing page (the server marks its shell) would only bounce back to itself through its folder link: it goes home.
const landing = !!document.querySelector('meta[name="handoff-landing"]');
export const folderUrl = landing ? "/" : "/" + folder + "/";
export const folderPages = landing ? "Home" : (folder.length <= 3 ? folder.toUpperCase() : folder.slice(0, 1).toUpperCase() + folder.slice(1)) + " pages";
