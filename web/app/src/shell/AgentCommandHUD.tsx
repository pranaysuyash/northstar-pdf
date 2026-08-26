import React, { useState, useRef } from "react";

export interface CommandItem {
  id: string;
  title: string;
  subtitle: string;
  category: "autofill" | "analysis" | "tools" | "security" | "document" | "export";
  shortcut?: string;
  icon: string;
  action: () => void;
}

interface AgentCommandHUDProps {
  isOpen: boolean;
  onClose: () => void;
  commands: CommandItem[];
}

export const AgentCommandHUD: React.FC<AgentCommandHUDProps> = ({ isOpen, onClose, commands }) => {
  // The parent unmounts this HUD whenever it closes, so local state resets
  // naturally on reopen — no prop-driven state adjustment required.
  const [query, setQuery] = useState("");
  const [selectedIndex, setSelectedIndex] = useState(0);
  const inputRef = useRef<HTMLInputElement>(null);

  const filteredCommands = commands.filter(
    (c) =>
      c.title.toLowerCase().includes(query.toLowerCase()) ||
      c.subtitle.toLowerCase().includes(query.toLowerCase()) ||
      c.category.toLowerCase().includes(query.toLowerCase())
  );

  const runCommand = (index: number) => {
    const command = filteredCommands[index];
    if (!command) return;
    command.action();
    onClose();
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "ArrowDown") {
      e.preventDefault();
      setSelectedIndex((prev) => (prev + 1) % Math.max(1, filteredCommands.length));
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setSelectedIndex((prev) => (prev - 1 + filteredCommands.length) % Math.max(1, filteredCommands.length));
    } else if (e.key === "Enter") {
      e.preventDefault();
      runCommand(selectedIndex);
    } else if (e.key === "Escape") {
      e.preventDefault();
      onClose();
    }
  };

  if (!isOpen) return null;

  return (
    <dialog
      open
      aria-label="Command palette"
      className="fixed inset-0 z-50 w-full h-full m-0"
      style={{ border: "none", padding: 0, background: "none", maxWidth: "none", maxHeight: "none" }}
    >
      {/* react-doctor-disable-next-line react-doctor/no-static-element-interactions react-doctor/no-noninteractive-element-interactions */}{/* Scrim click is a pointer convenience; keyboard users close via Esc and execute via Enter. */}
      <div
        className="w-full h-full flex items-start justify-center pt-24 bg-black/50 backdrop-blur-sm"
        onClick={(e) => {
          if (e.target === e.currentTarget) onClose();
        }}
        onKeyDown={handleKeyDown}
      >
      <div
        className="w-full max-w-xl bg-slate-900 ring-1 ring-slate-700/80 rounded-xl shadow-2xl overflow-hidden flex flex-col animate-in fade-in zoom-in-95 duration-150"
      >
        <div className="flex items-center px-4 py-3 border-b border-slate-800 bg-slate-950/60">
          <span className="text-slate-400 mr-2 text-lg" aria-hidden="true">⚡</span>
          <input
            ref={inputRef}
            type="text"
            autoFocus
            className="w-full bg-transparent text-slate-100 placeholder-slate-500 focus:outline-none text-base"
            placeholder="Type a command or search action (e.g. Autofill, OCR, Redact, Sign)..."
            aria-label="Search commands"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
          <kbd className="px-2 py-0.5 text-xs font-mono text-slate-400 bg-slate-800 border border-slate-700 rounded">
            ESC
          </kbd>
        </div>

        <div className="max-h-80 overflow-y-auto py-2" role="listbox" aria-label="Available commands">
          {filteredCommands.length === 0 ? (
            <div className="px-4 py-8 text-center text-sm text-slate-500" role="status">
              No actions match "{query}"
            </div>
          ) : (
            filteredCommands.map((cmd, idx) => {
              const isSelected = idx === selectedIndex;
              return (
                <button
                  type="button"
                  key={cmd.id}
                  role="option"
                  aria-selected={isSelected}
                  className={`w-full text-left flex items-center justify-between px-4 py-2.5 mx-2 rounded-lg cursor-pointer transition-colors ${
                    isSelected ? "bg-cyan-950/70 border border-cyan-700/60 text-cyan-200" : "text-slate-300 hover:bg-slate-800/60"
                  }`}
                  onClick={() => runCommand(idx)}
                  onMouseEnter={() => setSelectedIndex(idx)}
                >
                  <span className="flex items-center gap-3">
                    <span className="text-lg" aria-hidden="true">{cmd.icon}</span>
                    <span className="block">
                      <span className="block text-sm font-medium">{cmd.title}</span>
                      <span className="block text-xs text-slate-400">{cmd.subtitle}</span>
                    </span>
                  </span>
                  {cmd.shortcut && (
                    <kbd className="px-1.5 py-0.5 text-xs font-mono text-slate-400 bg-slate-800/80 border border-slate-700 rounded">
                      {cmd.shortcut}
                    </kbd>
                  )}
                </button>
              );
            })
          )}
        </div>

        <div className="px-4 py-2 bg-slate-950/80 border-t border-slate-800 flex items-center justify-between text-xs text-slate-500">
          <div className="flex items-center gap-3">
            <span>↑↓ Navigate</span>
            <span>↵ Execute</span>
          </div>
          <span className="font-mono text-slate-400">Northstar Native Agent HUD</span>
        </div>
      </div>
      </div>
    </dialog>
  );
};
