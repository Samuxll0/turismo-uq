package com.turismouq.app.repository;

import com.turismouq.app.entity.Habitacion;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface HabitacionRepository extends JpaRepository<Habitacion, Long> {
    List<Habitacion> findByAlojamientoIdAlojamientoOrderByNumeroNombreAsc(Long idAlojamiento);

    @Query("""
        SELECT h FROM Habitacion h
        JOIN FETCH h.alojamiento a
        JOIN FETCH a.municipio m
        WHERE h.idHabitacion = :id
    """)
    Optional<Habitacion> findByIdWithDetails(@Param("id") Long id);

    @Query("""
        SELECT h FROM Habitacion h
        JOIN FETCH h.alojamiento a
        JOIN FETCH a.municipio m
        ORDER BY a.nombre, h.numeroNombre
    """)
    List<Habitacion> findAllWithDetails();
}
