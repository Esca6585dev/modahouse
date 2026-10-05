type P = { size?: number };
const base = (size: number) => ({
  width: size, height: size, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor",
  strokeWidth: 2, strokeLinecap: "round" as const, strokeLinejoin: "round" as const, "aria-hidden": true,
});

export const SearchIcon = ({ size = 18 }: P) => (<svg {...base(size)}><circle cx="11" cy="11" r="7" /><path d="m20 20-3.5-3.5" /></svg>);
export const BellIcon = ({ size = 22 }: P) => (<svg {...base(size)}><path d="M6 8a6 6 0 1 1 12 0c0 7 3 9 3 9H3s3-2 3-9" /><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0" /></svg>);
export const ShareIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M12 3v13" /><path d="m7 8 5-5 5 5" /><path d="M5 14v5a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-5" /></svg>);
export const MoreIcon = ({ size = 18 }: P) => (<svg {...base(size)}><circle cx="5" cy="12" r="1.2" /><circle cx="12" cy="12" r="1.2" /><circle cx="19" cy="12" r="1.2" /></svg>);
export const PlusIcon = ({ size = 22 }: P) => (<svg {...base(size)}><path d="M12 5v14M5 12h14" /></svg>);
export const BackIcon = ({ size = 22 }: P) => (<svg {...base(size)}><path d="M19 12H5" /><path d="m12 19-7-7 7-7" /></svg>);
export const UploadIcon = ({ size = 28 }: P) => (<svg {...base(size)}><path d="M12 16V4" /><path d="m7 9 5-5 5 5" /><path d="M4 20h16" /></svg>);
export const HeartIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M19.5 12.6 12 20l-7.5-7.4A4.8 4.8 0 1 1 12 6.6a4.8 4.8 0 1 1 7.5 6Z" /></svg>);
export const LinkIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M10 13a5 5 0 0 0 7.5.5l3-3a5 5 0 0 0-7-7l-1.7 1.7" /><path d="M14 11a5 5 0 0 0-7.5-.5l-3 3a5 5 0 0 0 7 7l1.7-1.7" /></svg>);
export const HomeIcon = ({ size = 22 }: P) => (<svg {...base(size)}><path d="m3 10 9-7 9 7v10a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1Z" /></svg>);
export const CheckIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="m5 12 5 5 9-10" /></svg>);
export const LockIcon = ({ size = 16 }: P) => (<svg {...base(size)}><rect x="4" y="11" width="16" height="10" rx="2" /><path d="M8 11V7a4 4 0 0 1 8 0v4" /></svg>);
export const EditIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M12 20h9" /><path d="M16.5 3.5a2.1 2.1 0 1 1 3 3L7 19l-4 1 1-4Z" /></svg>);
export const TrashIcon = ({ size = 18 }: P) => (<svg {...base(size)}><path d="M3 6h18" /><path d="M8 6V4h8v2" /><path d="M19 6l-1 14H6L5 6" /></svg>);
export const CloseIcon = ({ size = 20 }: P) => (<svg {...base(size)}><path d="M18 6 6 18M6 6l12 12" /></svg>);
export const ExternalIcon = ({ size = 16 }: P) => (<svg {...base(size)}><path d="M14 4h6v6" /><path d="M20 4 10 14" /><path d="M19 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1h5" /></svg>);
export const ChevronDownIcon = ({ size = 16 }: P) => (<svg {...base(size)}><path d="m6 9 6 6 6-6" /></svg>);
