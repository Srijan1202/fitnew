'use client';

import { useSearchParams } from 'next/navigation';
import { Suspense } from 'react';

import { ExerciseEditor } from '@/components/ExerciseEditor';

/** One exercise, by `?id=` (a static page); the list also opens it in a side panel (beta 5.3). */
export default function ExerciseEditorPage() {
  return (
    <Suspense>
      <FromAddress />
    </Suspense>
  );
}

function FromAddress() {
  return <ExerciseEditor id={useSearchParams().get('id') ?? ''} />;
}
