package com.turismouq.app.repository;

import com.turismouq.app.entity.Reserva;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ReservaRepository extends JpaRepository<Reserva, Long> {

    @Query("""
        SELECT r FROM Reserva r
        JOIN FETCH r.cliente c
        ORDER BY r.idReserva DESC
    """)
    List<Reserva> findTop20Recent();
}
