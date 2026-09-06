import { create } from "zustand";

type PresentationState = {
  isSourcePanelOpen: boolean;
  setSourcePanelOpen: (isOpen: boolean) => void;
};

export const usePresentationStore = create<PresentationState>((set) => ({
  isSourcePanelOpen: false,
  setSourcePanelOpen: (isSourcePanelOpen) => set({ isSourcePanelOpen }),
}));
