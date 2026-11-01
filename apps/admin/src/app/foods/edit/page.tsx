'use client';

import { useSearchParams } from 'next/navigation';
import { Suspense } from 'react';

import { FoodEditor } from '@/components/FoodEditor';

/** One food, by `?id=` (a static page); the list also opens it in a side panel (beta 5.3). */
export default function FoodEditorPage() {
  return (
    <Suspense>
      <FromAddress />
    </Suspense>
  );
}

function FromAddress() {
  return <FoodEditor id={useSearchParams().get('id') ?? ''} />;
}
