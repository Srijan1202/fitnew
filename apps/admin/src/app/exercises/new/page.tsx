'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';

import { EMPTY_EXERCISE, ExerciseForm } from '@/components/ExerciseForm';
import { Header } from '@/components/ui';

export default function NewExercise() {
  const router = useRouter();
  return (
    <>
      <p><Link href="/exercises">← Exercises</Link></p>
      <Header eyebrow="Library" title="New exercise" />
      <ExerciseForm initial={EMPTY_EXERCISE} id={null} onSaved={(x) => router.push(`/exercises/${x.id}`)} />
    </>
  );
}
