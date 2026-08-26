import React, { useState, useEffect, useRef } from "react";

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
  const [query, setQuery] = useState("");
  const [selectedIndex, setSelectedIndex] = useState(0);
  const inputRef = useRef<HTMLInputElement>(null);

  const filteredCommands = commands.filter(
    (c) =>
      c.title.toLowerCase().includes(query.toLowerCase()) ||
      c.subtitle.toLowerCase().includes(query.toLowerCase()) ||
      c.category.toLowerCase().includes(query.toLowerCase())
  );

  useEffect(() => {
    if (isOpen) {
      setQuery("");
      setSelectedIndex(0);
      setTimeout(() => inputRef.current?.focus(), 50);
    }
  }, [isOpen]);

  useEffect(() => {
    setSelectedIndex(0);
  }, [query]);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "ArrowDown") {
      e.preventDefault();
      setSelectedIndex((prev) => (prev + 1) % Math.max(1, filteredCommands.length));
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setSelectedIndex((prev) => (prev - 1 + filteredCommands.length) % Math.max(1, filteredCommands.length));
    } else if (e.key === "Enter") {
      e.preventDefault();
      if (filteredCommands[selectedIndex]) {
        filteredCommands[selectedIndex].action();
        onClose();
      }
    } else if (e.key === "Escape") {
      e.preventDefault();
      onClose();
    }
  };

  if (!isOpen) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-start justify-center pt-24 bg-black/50 backdrop-blur-sm"
      onClick={onClose}
    >
      <div
        className="w-full max-w-xl bg-slate-900 border border-slate-700/80 rounded-xl shadow-2xl overflow-hidden flex flex-col animate-in fade-in zoom-in-95 duration-150"
        onClick={(e) => e.stopPropagation()}
        onKeyDown={handleKeyDown}
      >
        <div className="flex items-center px-4 py-3 border-b border-slate-800 bg-slate-950/60">
          <span className="text-slate-400 mr-2 text-lg">⚡</span>
          <input
            ref={inputRef}
            type="text"
            className="w-full bg-transparent text-slate-100 placeholder-slate-500 focus:outline-none text-base"
            placeholder="Type a command or search action (e.g. Autofill, OCR, Redact, Sign)..."
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
          <kbd className="px-2 py-0.5 text-xs font-mono text-slate-400 bg-slate-800 border border-slate-700 rounded">
            ESC
          </kbd>
        </div>

        <div className="max-h-80 overflow-y-auto py-2">
          {filteredCommands.length === 0 ? (
            <div className="px-4 py-8 text-center text-sm text-slate-500">
              No actions match "{query}"
            </div>
          ) : (
            filteredCommands.map((cmd, idx) => {
              const isSelected = idx === selectedIndex;
              return (
                <div
                  key={cmd.id}
                  className={`flex items-center justify-between px-4 py-2.5 mx-2 rounded-lg cursor-pointer transition-colors ${
                    isSelected ? "bg-cyan-950/70 border border-cyan-700/60 text-cyan-200" : "text-slate-300 hover:bg-slate-800/60"
                  }`}
                  onClick={() => {
                    cmd.action();
                    onClose();
                  }}
                  onMouseEnter={() => setSelectedIndex(idx)}
                >
                  <div className="flex items-center space-x-3">
                    <span className="text-lg">{cmd.icon}</span>
                    <div>
                      <div className="text-sm font-medium">{cmd.title}</div>
                      <div className="text-xs text-slate-400">{cmd.subtitle}</div>
                    </div>
                  </div>
                  {cmd.shortcut && (
                    <kbd className="px-1.5 py-0.5 text-xs font-mono text-slate-400 bg-slate-800/80 border border-slate-700 rounded">
                      {cmd.shortcut}
                    </kbd>
                  )}
                </div>
              );
            })
          )}
        </div>

        <div className="px-4 py-2 bg-slate-950/80 border-t border-slate-800 flex items-center justify-between text-xs text-slate-500">
          <div className="flex items-center space-x-3">
            <span>↑↓ Navigate</span>
            <span>↵ Execute</span>
          </div>
          <span className="font-mono text-slate-400">Northstar Native Agent HUD</span>
        </div>
      </div>
    </div>
  );
};
