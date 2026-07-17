import { useEffect, useState } from 'react';

import { getFile, listFiles, type CreateSessionResponse, type SessionFileRef } from '../api';
import { CodeViewer } from './CodeViewer';
import { FileList } from './FileList';
import { RunTestPanel } from './RunTestPanel';
import { SimulationChat } from './SimulationChat';
import './sandbox.css';

type Props = {
  session: CreateSessionResponse;
};

/**
 * The sandbox layer: file list | code viewer + run-test | streaming AI chat, all sharing one
 * session. When the copilot edits a file (file_updated), we refetch the listing and, if the edited
 * file is the one on screen, its content — so the viewer reflects the AI's change immediately.
 */
export function SandboxView({ session }: Props) {
  const sessionId = session.session_id;
  const [files, setFiles] = useState<SessionFileRef[]>(session.files);
  const [selected, setSelected] = useState<string>(session.files[0]?.path ?? '');
  const [content, setContent] = useState('');

  useEffect(() => {
    if (!selected) return;
    let active = true;
    getFile(sessionId, selected)
      .then((file) => {
        if (active) setContent(file.content);
      })
      .catch(() => {
        if (active) setContent('// Failed to load file.');
      });
    return () => {
      active = false;
    };
  }, [sessionId, selected]);

  const handleFileUpdated = async (path: string) => {
    try {
      setFiles(await listFiles(sessionId));
      if (path === selected) {
        setContent((await getFile(sessionId, path)).content);
      }
    } catch {
      // Best-effort refresh; selecting the file again will retry.
    }
  };

  return (
    <div className="sandbox-grid">
      <FileList files={files} selected={selected} onSelect={setSelected} />
      <div className="sandbox-center">
        <CodeViewer content={content} path={selected} />
        <RunTestPanel session={session} />
      </div>
      <SimulationChat sessionId={sessionId} onFileUpdated={handleFileUpdated} />
    </div>
  );
}
